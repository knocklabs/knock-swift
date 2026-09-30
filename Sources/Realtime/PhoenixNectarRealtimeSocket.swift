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

    /// - Parameter connectParams: Read on every connection attempt, including automatic reconnects. Defaults to
    ///   `configuration.connectParams`.
    init(
        configuration: RealtimeSocketConfiguration,
        connectParams: (@Sendable () -> [String: String])? = nil,
        joinTimeout: Duration = .seconds(10),
        logger: RealtimeLogger = .disabled
    ) throws {
        let connectParams = connectParams ?? { [params = configuration.connectParams] in params }
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
                hub.handle(message)
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
        // Signals for a previous join of this topic are stale once a new join starts.
        signalHub.remove(topic: topic)
        do {
            let channel = try await socket.joinChannel(topic, params: params, policy: joinPolicy)
            return PhoenixNectarRealtimeChannel(channel: channel, signalStream: signalHub.register(topic: topic))
        } catch let error as PhoenixError {
            throw Self.joinError(from: error)
        } catch let error as EncodingError {
            throw RealtimeJoinError.unrecoverable(reason: "Encoding the join parameters failed: \(error)")
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

/// Routes inbound frames to the signal stream of the joined channel they belong to.
private final class ChannelSignalHub: Sendable {
    private struct State {
        var classifier = ChannelSignalClassifier()
        var continuations: [String: AsyncStream<RealtimeChannelSignal>.Continuation] = [:]
    }

    private let state = LockIsolated(State())

    func register(topic: String) -> AsyncStream<RealtimeChannelSignal> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeChannelSignal.self, bufferingPolicy: .unbounded)
        let previous = state.withLock { state in
            defer { state.continuations[topic] = continuation }
            return state.continuations[topic]
        }
        previous?.finish()
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

    func handle(_ message: PhoenixMessage) {
        let frame = ChannelSignalClassifier.Frame(
            topic: message.topic.rawValue,
            event: message.event,
            ref: message.ref,
            joinRef: message.joinRef,
            status: message.pushStatus
        )
        // Every frame updates the classifier, including replies to explicit joins, which arrive before their topic is
        // registered and so are never delivered as signals.
        let delivery = state.withLock { state -> (AsyncStream<RealtimeChannelSignal>.Continuation, RealtimeChannelSignal)? in
            let signal = state.classifier.signal(for: frame) {
                PhoenixNectarRealtimeSocket.reason(fromResponse: try? message.replyEnvelope().decode([String: AnyCodable].self))
            }
            guard let signal, let continuation = state.continuations[frame.topic] else { return nil }
            return (continuation, signal)
        }
        if let (continuation, signal) = delivery {
            continuation.yield(signal)
        }
    }
}

/// Turns inbound channel frames into signals, ignoring frames that belong to an earlier join of the topic.
///
/// PhoenixNectar drops stale frames before delivering channel messages, but the metrics hook sees every frame. Refs are
/// increasing counters, so a frame is stale when its ref (for replies) or join ref (for errors and closes) is older than
/// the latest join the classifier knows about.
internal struct ChannelSignalClassifier: Sendable {
    struct Frame: Sendable {
        var topic: String
        var event: PhoenixEvent
        var ref: String?
        var joinRef: String?
        var status: PushStatus?
    }

    /// The ref of the latest join pushed for each topic.
    private var latestJoinRefs: [String: UInt64] = [:]
    /// The join ref of the latest join the server accepted for each topic.
    private var acceptedJoinRefs: [String: UInt64] = [:]

    mutating func joinSent(topic: String, ref: String?) {
        guard let ref = ref.flatMap(UInt64.init) else { return }
        latestJoinRefs[topic] = max(ref, latestJoinRefs[topic] ?? 0)
    }

    /// The signal for `frame`, or `nil` if it isn't one or belongs to an earlier join.
    ///
    /// The feed channel never pushes, so every reply on its topic is a reply to a join.
    mutating func signal(for frame: Frame, reason: () -> String) -> RealtimeChannelSignal? {
        switch frame.event {
        case .system(.reply):
            // Replies can arrive before the join's send is reported, so only replies to older joins are stale.
            guard let ref = frame.ref.flatMap(UInt64.init), ref >= (latestJoinRefs[frame.topic] ?? 0) else { return nil }
            latestJoinRefs[frame.topic] = ref
            switch frame.status {
            case .ok:
                if let joinRef = frame.joinRef.flatMap(UInt64.init) {
                    acceptedJoinRefs[frame.topic] = joinRef
                }
                return .rejoined
            case .error:
                return .rejoinRejected(reason: reason())
            case .timeout, nil:
                return nil
            }
        case .system(.error):
            return isCurrent(frame) ? .errored : nil
        case .system(.close):
            return isCurrent(frame) ? .closed : nil
        default:
            return nil
        }
    }

    private func isCurrent(_ frame: Frame) -> Bool {
        guard let joinRef = frame.joinRef.flatMap(UInt64.init), let accepted = acceptedJoinRefs[frame.topic] else { return true }
        return joinRef >= accepted
    }
}
