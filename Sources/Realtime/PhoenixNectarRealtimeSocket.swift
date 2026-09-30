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
    private let joinTimeout: Duration
    private let logger: RealtimeLogger

    init(
        configuration: RealtimeSocketConfiguration,
        joinTimeout: Duration = .seconds(10),
        heartbeatInterval: Duration = .seconds(30),
        reconnectDelay: @escaping @Sendable (Int) -> Duration = RealtimeBackoff.delay(attempt:),
        logger: RealtimeLogger = .disabled
    ) throws {
        let connectParams = configuration.connectParams
        self.socket = try Socket(
            endpoint: configuration.endpoint,
            configuration: Socket.Configuration(
                defaultRequestPolicy: RequestPolicy(timeout: joinTimeout),
                connectionPolicy: ConnectionPolicy(
                    heartbeatInterval: heartbeatInterval,
                    reconnectBackoff: reconnectDelay
                )
            ),
            connectParamsProvider: { connectParams }
        )
        self.joinTimeout = joinTimeout
        self.logger = logger
    }

    func connect() async throws {
        let hub = signalHub
        let logger = logger
        await socket.setMetricsHook { event in
            switch event {
            case .frameReceived(let message):
                hub.handle(message)
                logger("Received \(message.event.rawValue) on \(message.topic.rawValue)")
            case .connectionStateChanged(let state):
                logger("Socket state changed: \(state)")
            case .pushTimedOut(let ref):
                logger("Push \(ref) timed out")
            case .transport(.error(let error)):
                logger("Socket transport error: \(error)")
            case .transport(.close(let code, let reason)):
                logger("Socket closed (\(code)) \(reason ?? "")")
            default:
                break
            }
        }
        do {
            try await socket.connect()
        } catch {
            throw RealtimeJoinError.transient(reason: error.localizedDescription)
        }
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
            let channel = try await socket.joinChannel(topic, params: params, policy: RequestPolicy(timeout: joinTimeout))
            return PhoenixNectarRealtimeChannel(channel: channel, signals: signalHub.register(topic: topic))
        } catch let error as PhoenixError {
            throw Self.joinError(from: error)
        }
    }

    static func joinError(from error: PhoenixError) -> RealtimeJoinError {
        switch error {
        case .serverError(let reply):
            return .rejected(reason: reason(from: reply))
        case .timeout, .notConnected, .channelClosed, .bufferOverflow, .protocolViolation:
            return .transient(reason: error.localizedDescription)
        case .encodingFailure, .decodingFailure, .malformedEndpoint:
            return .rejected(reason: error.localizedDescription)
        }
    }

    static func reason(from reply: PhoenixReply) -> String {
        guard let response = try? reply.decode([String: AnyCodable].self), !response.isEmpty else {
            return "unknown"
        }
        if let reason = response["reason"]?.value as? String {
            return reason
        }
        return response.description
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
    let signalBroadcaster: ChannelSignalBroadcaster

    init(channel: Channel, signals: ChannelSignalBroadcaster) {
        self.channel = channel
        self.signalBroadcaster = signals
    }

    var topic: String {
        channel.topic.rawValue
    }

    func messages(event: String) async -> AsyncThrowingStream<[String: AnyCodable], Error> {
        await channel.subscribe(to: Event<[String: AnyCodable]>(event))
    }

    func signals() async -> AsyncStream<RealtimeChannelSignal> {
        signalBroadcaster.makeStream()
    }
}

/// Fans channel signals out to any number of streams. Finishing the broadcaster finishes every stream.
private final class ChannelSignalBroadcaster: Sendable {
    private struct State {
        var continuations: [UUID: AsyncStream<RealtimeChannelSignal>.Continuation] = [:]
        var isFinished = false
    }

    private let state = LockIsolated(State())

    func makeStream() -> AsyncStream<RealtimeChannelSignal> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeChannelSignal.self, bufferingPolicy: .unbounded)
        let id = UUID()
        let registered = state.withLock { state -> Bool in
            guard !state.isFinished else { return false }
            state.continuations[id] = continuation
            return true
        }
        guard registered else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.continuations.removeValue(forKey: id) }
        }
        return stream
    }

    func yield(_ signal: RealtimeChannelSignal) {
        let continuations = state.withLock { Array($0.continuations.values) }
        continuations.forEach { $0.yield(signal) }
    }

    func finish() {
        let continuations = state.withLock { state -> [AsyncStream<RealtimeChannelSignal>.Continuation] in
            state.isFinished = true
            defer { state.continuations.removeAll() }
            return Array(state.continuations.values)
        }
        continuations.forEach { $0.finish() }
    }
}

/// Routes inbound frames to the signal broadcaster of the joined channel they belong to.
private final class ChannelSignalHub: Sendable {
    private let broadcasters = LockIsolated<[String: ChannelSignalBroadcaster]>([:])

    func register(topic: String) -> ChannelSignalBroadcaster {
        let broadcaster = ChannelSignalBroadcaster()
        let previous = broadcasters.withLock { broadcasters in
            defer { broadcasters[topic] = broadcaster }
            return broadcasters[topic]
        }
        previous?.finish()
        return broadcaster
    }

    func remove(topic: String) {
        broadcasters.withLock { $0.removeValue(forKey: topic) }?.finish()
    }

    func finishAll() {
        let all = broadcasters.withLock { broadcasters in
            defer { broadcasters.removeAll() }
            return Array(broadcasters.values)
        }
        all.forEach { $0.finish() }
    }

    func handle(_ message: PhoenixMessage) {
        guard let broadcaster = broadcasters.value[message.topic.rawValue] else { return }
        switch message.event {
        case .system(.error):
            broadcaster.yield(.errored)
        case .system(.close):
            broadcaster.yield(.closed)
        // The feed channel never pushes, and the reply to the initial join arrives before the topic is registered
        // here, so any reply on a registered topic is the reply to an automatic rejoin.
        case .system(.reply) where message.pushStatus == .ok:
            broadcaster.yield(.rejoined)
        case .system(.reply) where message.pushStatus == .error:
            let reason = (try? message.replyEnvelope()).map(PhoenixNectarRealtimeSocket.reason(from:)) ?? "unknown"
            broadcaster.yield(.rejoinRejected(reason: reason))
        default:
            break
        }
    }
}
