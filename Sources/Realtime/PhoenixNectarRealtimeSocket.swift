//
//  PhoenixNectarRealtimeSocket.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
internal import PhoenixNectar

/// `RealtimeSocket` backed by a PhoenixNectar `Socket`.
///
/// PhoenixNectar owns heartbeats, reconnects (with the backoff below) and rejoining channels after a reconnect.
/// This adapter adds the pieces PhoenixNectar does not surface directly: server-side channel crashes (`phx_error`),
/// server-side channel closes (`phx_close`) and rejected automatic rejoins, all observed through the metrics hook.
internal final class PhoenixNectarRealtimeSocket: RealtimeSocket {
    private let socket: Socket
    private let signalHub = ChannelSignalHub()
    private let joinPolicy: RequestPolicy
    private let logger: RealtimeLogger

    init(configuration: RealtimeSocketConfiguration, joinTimeout: Duration = .seconds(10), logger: RealtimeLogger = .disabled) throws {
        let connectParams = configuration.connectParams
        let joinPolicy = RequestPolicy(timeout: joinTimeout)
        self.socket = try Socket(
            endpoint: configuration.endpoint,
            configuration: Socket.Configuration(
                // Used for the automatic rejoins PhoenixNectar sends after a reconnect.
                defaultRequestPolicy: joinPolicy,
                connectionPolicy: ConnectionPolicy(
                    heartbeatInterval: .seconds(30),
                    reconnectBackoff: RealtimeBackoff.delay(attempt:)
                )
            ),
            connectParamsProvider: { connectParams }
        )
        self.joinPolicy = joinPolicy
        self.logger = logger
    }

    func connect() async throws {
        let hub = signalHub
        let logger = logger
        await socket.setMetricsHook { event in
            switch event {
            case .frameReceived(let message):
                hub.handle(message)
                logger(.debug, "Received \(message.event.rawValue) on \(message.topic.rawValue)")
            case .connectionStateChanged(let state):
                logger(.debug, "Socket state changed: \(state)")
            case .pushTimedOut(let ref):
                logger(.debug, "Push \(ref) timed out")
            case .transport(.error(let error)):
                logger(.debug, "Socket transport error: \(error)")
            case .transport(.close(let code, let reason)):
                logger(.debug, "Socket closed (\(code)) \(reason ?? "")")
            default:
                break
            }
        }
        try await socket.connect()
    }

    func disconnect() async {
        signalHub.finishAll()
        await socket.disconnect()
    }

    func connectionStates() async -> AsyncStream<RealtimeConnectionState> {
        let source = await socket.connectionStateStream(bufferingPolicy: .unbounded)
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await state in source {
                    continuation.yield(Self.map(state))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func join<Params: Encodable & Sendable>(topic: String, params: Params) async throws -> any RealtimeChannel {
        // Signals for a previous join of this topic are stale once a new join starts.
        signalHub.remove(topic: topic)
        do {
            let channel = try await socket.joinChannel(topic, params: params, policy: joinPolicy)
            return PhoenixNectarRealtimeChannel(channel: channel, signalStream: signalHub.register(topic: topic))
        } catch let error as PhoenixError {
            throw Self.joinError(from: error)
        }
    }

    static func joinError(from error: PhoenixError) -> RealtimeJoinError {
        switch error {
        case .serverError(let reply):
            return .rejected(reason: reason(fromResponse: try? reply.decode([String: AnyCodable].self)))
        case .timeout, .notConnected, .channelClosed, .bufferOverflow, .protocolViolation:
            return .transient(reason: error.localizedDescription)
        case .encodingFailure, .decodingFailure, .malformedEndpoint:
            return .unrecoverable(reason: error.localizedDescription)
        }
    }

    /// The `reason` Phoenix puts in error replies (for example `{"reason": "unauthorized"}`).
    static func reason(fromResponse response: [String: AnyCodable]?) -> String {
        guard let response, !response.isEmpty else { return "unknown" }
        if let reason = response["reason"]?.value as? String {
            return reason
        }
        return response.description
    }

    /// Maps an inbound frame on a joined topic to a channel signal.
    ///
    /// The feed channel never pushes, and the reply to an explicit join arrives before its topic is registered with
    /// the signal hub, so a reply on a registered topic is the reply to an automatic rejoin.
    static func signal(for event: PhoenixEvent, status: PushStatus?, reason: () -> String) -> RealtimeChannelSignal? {
        switch event {
        case .system(.error):
            return .errored
        case .system(.close):
            return .closed
        case .system(.reply) where status == .ok:
            return .rejoined
        case .system(.reply) where status == .error:
            return .rejoinRejected(reason: reason())
        default:
            return nil
        }
    }

    private static func map(_ state: ConnectionState) -> RealtimeConnectionState {
        switch state {
        case .idle:
            return .idle
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .reconnecting(let attempt, _):
            return .reconnecting(attempt: attempt)
        case .disconnected(let code, let reason):
            return .disconnected(code: code, reason: reason)
        case .failed(let error):
            return .failed(reason: error.localizedDescription)
        }
    }
}

private struct PhoenixNectarRealtimeChannel: RealtimeChannel {
    let channel: Channel
    let signalStream: AsyncStream<RealtimeChannelSignal>

    var topic: String {
        channel.topic.rawValue
    }

    func messages(event: String) async -> AsyncThrowingStream<[String: AnyCodable], Error> {
        await channel.subscribe(to: Event<[String: AnyCodable]>(event))
    }

    func signals() async -> AsyncStream<RealtimeChannelSignal> {
        signalStream
    }
}

/// Routes inbound frames to the signal stream of the joined channel they belong to.
private final class ChannelSignalHub: Sendable {
    private let continuations = LockIsolated<[String: AsyncStream<RealtimeChannelSignal>.Continuation]>([:])

    func register(topic: String) -> AsyncStream<RealtimeChannelSignal> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeChannelSignal.self, bufferingPolicy: .unbounded)
        let previous = continuations.withLock { continuations in
            defer { continuations[topic] = continuation }
            return continuations[topic]
        }
        previous?.finish()
        return stream
    }

    func remove(topic: String) {
        continuations.withLock { $0.removeValue(forKey: topic) }?.finish()
    }

    func finishAll() {
        let all = continuations.withLock { continuations in
            defer { continuations.removeAll() }
            return Array(continuations.values)
        }
        all.forEach { $0.finish() }
    }

    func handle(_ message: PhoenixMessage) {
        guard let continuation = continuations.value[message.topic.rawValue],
              let signal = PhoenixNectarRealtimeSocket.signal(
                  for: message.event,
                  status: message.pushStatus,
                  reason: { PhoenixNectarRealtimeSocket.reason(fromResponse: try? message.replyEnvelope().decode([String: AnyCodable].self)) }
              )
        else { return }
        continuation.yield(signal)
    }
}
