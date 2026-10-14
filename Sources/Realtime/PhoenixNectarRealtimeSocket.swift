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

    /// - Parameter connectParams: Read on every connection attempt, including automatic reconnects.
    init(
        endpoint: String,
        connectParams: @escaping @Sendable () -> [String: String],
        joinTimeout: Duration = .seconds(10),
        logger: RealtimeLogger = .disabled
    ) throws {
        let joinPolicy = RequestPolicy(timeout: joinTimeout)
        self.socket = try Socket(
            endpoint: endpoint,
            configuration: Socket.Configuration(
                // Used for the automatic rejoins PhoenixNectar sends after a reconnect.
                defaultRequestPolicy: joinPolicy,
                connectionPolicy: ConnectionPolicy(
                    heartbeatInterval: .seconds(30),
                    reconnectBackoff: RealtimeBackoff.delay(attempt:)
                )
            ),
            connectParamsProvider: { connectParams() }
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
                let frame = ChannelSignalClassifier.Frame(
                    topic: message.topic.rawValue,
                    event: message.event,
                    ref: message.ref,
                    joinRef: message.joinRef,
                    status: message.pushStatus
                )
                hub.handle(frame) {
                    Self.reason(fromResponse: try? message.replyEnvelope().decode([String: AnyCodable].self))
                }
                logger(.debug, "Received \(message.event.rawValue) on \(message.topic.rawValue)")
            case .frameSent(let ref, let topic, .system(.join)), .frameBuffered(let ref, let topic, .system(.join)):
                hub.joinSent(topic: topic.rawValue, ref: ref)
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
        // Registered before the join is sent so a crash right after the join reply isn't missed. This replaces the
        // stream of any earlier join of the topic.
        let signals = signalHub.register(topic: topic)
        do {
            let channel = try await socket.joinChannel(topic, params: params, policy: joinPolicy)
            return PhoenixNectarRealtimeChannel(channel: channel, signalStream: signals)
        } catch {
            signalHub.remove(topic: topic)
            switch error {
            case let error as PhoenixError:
                throw Self.joinError(from: error)
            case let error as EncodingError:
                throw RealtimeJoinError.unrecoverable(reason: "Encoding the join parameters failed: \(error)")
            default:
                throw error
            }
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

/// Routes inbound frames to the signal stream of the channel they belong to.
internal final class ChannelSignalHub: Sendable {
    private struct State {
        var classifier = ChannelSignalClassifier()
        var continuations: [String: AsyncStream<RealtimeChannelSignal>.Continuation] = [:]
    }

    private let state = LockIsolated(State())

    func register(topic: String) -> AsyncStream<RealtimeChannelSignal> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeChannelSignal.self, bufferingPolicy: .unbounded)
        state.withLock { $0.continuations.updateValue(continuation, forKey: topic) }?.finish()
        return stream
    }

    func remove(topic: String) {
        state.withLock { $0.continuations.removeValue(forKey: topic) }?.finish()
    }

    func finishAll() {
        let all = state.withLock { state in
            defer { state.continuations.removeAll() }
            return Array(state.continuations.values)
        }
        all.forEach { $0.finish() }
    }

    func joinSent(topic: String, ref: String?) {
        state.withLock { $0.classifier.joinSent(topic: topic, ref: ref) }
    }

    /// Every frame updates the classifier, even on a topic with no stream. A registered join's own `ok` reply is
    /// delivered as `.rejoined`.
    func handle(_ frame: ChannelSignalClassifier.Frame, reason: () -> String) {
        let delivery = state.withLock { state -> (AsyncStream<RealtimeChannelSignal>.Continuation, RealtimeChannelSignal)? in
            let signal = state.classifier.signal(for: frame, reason: reason)
            guard let signal, let continuation = state.continuations[frame.topic] else { return nil }
            return (continuation, signal)
        }
        if let (continuation, signal) = delivery {
            continuation.yield(signal)
        }
    }
}
