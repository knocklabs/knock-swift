//
//  RealtimeFakes.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
@testable import Knock

/// A `RealtimeSocket` whose transport states, join replies and channel traffic are driven by the test.
final class FakeRealtimeSocket: RealtimeSocket {
    enum JoinBehavior: Sendable {
        case succeed
        case reject(String)
        case fail(String)
        case failUnrecoverably(String)
        /// Suspends until the join task is cancelled.
        case hang
    }

    struct JoinRequest: Sendable, Equatable {
        let topic: String
        let params: FeedChannelJoinParams?
    }

    private struct State {
        var connectCount = 0
        var disconnectCount = 0
        var connectError: String?
        var joinBehaviors: [JoinBehavior] = []
        var joinRequests: [JoinRequest] = []
        var channels: [FakeRealtimeChannel] = []
        var stateContinuations: [AsyncStream<RealtimeConnectionState>.Continuation] = []
        var currentState = RealtimeConnectionState.idle
        var isDisconnected = false
    }

    let configuration: RealtimeSocketConfiguration
    private let state = LockIsolated(State())

    init(configuration: RealtimeSocketConfiguration) {
        self.configuration = configuration
    }

    // MARK: Test controls

    var connectCount: Int { state.value.connectCount }
    var disconnectCount: Int { state.value.disconnectCount }
    var joinRequests: [JoinRequest] { state.value.joinRequests }
    var channels: [FakeRealtimeChannel] { state.value.channels }
    var lastChannel: FakeRealtimeChannel? { state.value.channels.last }
    var stateSubscriberCount: Int { state.value.stateContinuations.count }

    func failConnect(with reason: String) {
        state.withLock { $0.connectError = reason }
    }

    /// Queues how the next joins behave. Joins beyond the queue succeed.
    func enqueueJoins(_ behaviors: JoinBehavior...) {
        state.withLock { $0.joinBehaviors.append(contentsOf: behaviors) }
    }

    func emit(_ transportState: RealtimeConnectionState) {
        let continuations = state.withLock { state in
            state.currentState = transportState
            return state.stateContinuations
        }
        continuations.forEach { $0.yield(transportState) }
    }

    // MARK: RealtimeSocket

    func connect() async throws {
        let error = state.withLock { state -> String? in
            state.connectCount += 1
            return state.connectError
        }
        if let error {
            throw TestError(reason: error)
        }
        emit(.connecting)
    }

    func disconnect() async {
        let (continuations, channels) = state.withLock { state in
            state.disconnectCount += 1
            state.isDisconnected = true
            defer { state.stateContinuations.removeAll() }
            return (state.stateContinuations, state.channels)
        }
        continuations.forEach {
            $0.yield(.disconnected(code: 1000, reason: nil))
            $0.finish()
        }
        channels.forEach { $0.finishAll() }
    }

    func connectionStates() async -> AsyncStream<RealtimeConnectionState> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeConnectionState.self, bufferingPolicy: .unbounded)
        let current = state.withLock { state -> RealtimeConnectionState? in
            guard !state.isDisconnected else { return nil }
            state.stateContinuations.append(continuation)
            return state.currentState
        }
        if let current {
            continuation.yield(current)
        } else {
            continuation.finish()
        }
        return stream
    }

    func join<Params: Encodable & Sendable>(topic: String, params: Params) async throws -> any RealtimeChannel {
        let behavior = state.withLock { state -> JoinBehavior in
            state.joinRequests.append(JoinRequest(topic: topic, params: params as? FeedChannelJoinParams))
            return state.joinBehaviors.isEmpty ? .succeed : state.joinBehaviors.removeFirst()
        }
        switch behavior {
        case .succeed:
            let channel = FakeRealtimeChannel(topic: topic)
            state.withLock { $0.channels.append(channel) }
            return channel
        case .reject(let reason):
            throw RealtimeJoinError.rejected(reason: reason)
        case .fail(let reason):
            throw RealtimeJoinError.transient(reason: reason)
        case .failUnrecoverably(let reason):
            throw RealtimeJoinError.unrecoverable(reason: reason)
        case .hang:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            throw CancellationError()
        }
    }
}

final class FakeRealtimeChannel: RealtimeChannel {
    private struct State {
        var messageContinuations: [String: [UUID: AsyncThrowingStream<[String: AnyCodable], Error>.Continuation]] = [:]
        var subscribeCounts: [String: Int] = [:]
        var signalContinuations: [AsyncStream<RealtimeChannelSignal>.Continuation] = []
    }

    let topic: String
    private let state = LockIsolated(State())

    init(topic: String) {
        self.topic = topic
    }

    func messages(event: String) async -> AsyncThrowingStream<[String: AnyCodable], Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [String: AnyCodable].self)
        let id = UUID()
        state.withLock { state in
            state.messageContinuations[event, default: [:]][id] = continuation
            state.subscribeCounts[event, default: 0] += 1
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.messageContinuations[event]?.removeValue(forKey: id) }
        }
        return stream
    }

    func signals() async -> AsyncStream<RealtimeChannelSignal> {
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeChannelSignal.self)
        state.withLock { $0.signalContinuations.append(continuation) }
        return stream
    }

    // MARK: Test controls

    func subscribeCount(for event: String) -> Int {
        state.value.subscribeCounts[event] ?? 0
    }

    func liveSubscriptionCount(for event: String) -> Int {
        state.value.messageContinuations[event]?.count ?? 0
    }

    var signalSubscriberCount: Int {
        state.value.signalContinuations.count
    }

    func push(_ event: String, _ payload: [String: AnyCodable] = [:]) {
        let continuations = state.value.messageContinuations[event]?.values.map { $0 } ?? []
        continuations.forEach { $0.yield(payload) }
    }

    func failMessages(_ event: String, error: Error) {
        let continuations = state.value.messageContinuations[event]?.values.map { $0 } ?? []
        continuations.forEach { $0.finish(throwing: error) }
    }

    /// Simulates the socket dropping: PhoenixNectar finishes every topic stream when the transport fails.
    func finishMessageStreams() {
        let continuations = state.value.messageContinuations.values.flatMap { $0.values }
        continuations.forEach { $0.finish() }
    }

    func send(_ signal: RealtimeChannelSignal) {
        state.value.signalContinuations.forEach { $0.yield(signal) }
    }

    func finishAll() {
        finishMessageStreams()
        let signals = state.withLock { state in
            defer { state.signalContinuations.removeAll() }
            return state.signalContinuations
        }
        signals.forEach { $0.finish() }
    }
}

/// Creates `FakeRealtimeSocket`s and remembers them.
final class FakeRealtimeSocketFactory: Sendable {
    private let sockets = LockIsolated<[FakeRealtimeSocket]>([])
    private let failure = LockIsolated<String?>(nil)
    private let configure = LockIsolated<(@Sendable (FakeRealtimeSocket) -> Void)?>(nil)

    var created: [FakeRealtimeSocket] { sockets.value }
    var last: FakeRealtimeSocket? { sockets.value.last }

    func failNextCreation(with reason: String) {
        failure.setValue(reason)
    }

    /// Runs `body` on every socket as it's created, before it's used.
    func onCreate(_ body: @escaping @Sendable (FakeRealtimeSocket) -> Void) {
        configure.setValue(body)
    }

    var make: RealtimeSocketFactory {
        { [sockets, failure, configure] configuration in
            if let reason = failure.withLock({ value -> String? in
                defer { value = nil }
                return value
            }) {
                throw TestError(reason: reason)
            }
            let socket = FakeRealtimeSocket(configuration: configuration)
            configure.value?(socket)
            sockets.withLock { $0.append(socket) }
            return socket
        }
    }
}

extension FeedRealtimeTarget {
    static func fixture(options: Knock.FeedClientOptions? = nil, userToken: String? = "token") -> FeedRealtimeTarget {
        .make(
            baseUrl: "https://api.knock.app",
            publishableKey: "pk_test",
            userToken: userToken,
            userId: "user-1",
            feedId: "feed-1",
            options: Knock.FeedClientOptions(archived: .exclude).mergeOptions(options: options)
        )
    }
}

extension FeedRealtimeSession.Policy {
    static let fast = FeedRealtimeSession.Policy(
        joinRetryDelay: { _ in .milliseconds(10) },
        maxReconnectAttemptsBeforeFirstConnection: 3
    )
}
