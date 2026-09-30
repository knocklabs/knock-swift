//
//  FeedRealtimeSession.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// Owns the realtime connection for one feed: the socket, the joined channel and the event subscribers.
///
/// Event subscriptions outlive individual connections. Subscribing before `connect`, or across a
/// disconnect/reconnect (for example when the app is backgrounded), keeps delivering events once the
/// channel is joined again.
internal actor FeedRealtimeSession {
    typealias TargetProvider = @Sendable (Knock.FeedClientOptions?) async throws -> FeedRealtimeTarget
    typealias Log = @Sendable (KnockLogger.LogType, String) -> Void

    struct Policy: Sendable {
        /// Delay before retrying a join that failed for a transient reason. `attempt` starts at 1.
        var joinRetryDelay: @Sendable (Int) -> Duration
        /// How many reconnect attempts to allow before the socket has ever connected. Once it has connected,
        /// reconnects are retried indefinitely.
        var maxReconnectAttemptsBeforeFirstConnection: Int

        static let `default` = Policy(
            joinRetryDelay: { RealtimeBackoff.delay(attempt: $0 + 1) },
            maxReconnectAttemptsBeforeFirstConnection: 6
        )
    }

    private enum Intent {
        case idle
        case active(Knock.FeedClientOptions?)
        case suspended(Knock.FeedClientOptions?)
    }

    private enum JoinPhase {
        case joining
        case waitingToRetry
        case joined
    }

    private struct Connection {
        let id = UUID()
        let target: FeedRealtimeTarget
        let socket: any RealtimeSocket
        var channel: (any RealtimeChannel)?
        var joinPhase = JoinPhase.joining
        var hasConnectedTransport = false
        var lastTransportFailure: String?
        var task: Task<Void, Never>?
        var monitorTask: Task<Void, Never>?
        var signalTask: Task<Void, Never>?

        func cancelTasks() {
            task?.cancel()
            monitorTask?.cancel()
            signalTask?.cancel()
        }
    }

    private struct Forwarder {
        let id: UUID
        let task: Task<Void, Never>
    }

    private let socketFactory: RealtimeSocketFactory
    private let targetProvider: TargetProvider
    private let policy: Policy
    private let log: Log

    private var intent = Intent.idle
    /// Incremented by every connect/disconnect/suspend so that a slow `connect` can tell it was superseded.
    private var requestGeneration = 0
    private var connection: Connection?
    private var isShutdown = false

    private(set) var state = Knock.FeedConnectionState.disconnected
    private var stateContinuations: [UUID: AsyncStream<Knock.FeedConnectionState>.Continuation] = [:]

    private var subscribers: [String: [UUID: AsyncStream<Knock.FeedEvent>.Continuation]] = [:]
    private var forwarders: [String: Forwarder] = [:]

    init(
        socketFactory: @escaping RealtimeSocketFactory,
        targetProvider: @escaping TargetProvider,
        policy: Policy = .default,
        log: @escaping Log = { _, _ in }
    ) {
        self.socketFactory = socketFactory
        self.targetProvider = targetProvider
        self.policy = policy
        self.log = log
    }

    deinit {
        connection?.cancelTasks()
        if let socket = connection?.socket {
            Task { await socket.disconnect() }
        }
        forwarders.values.forEach { $0.task.cancel() }
        subscribers.values.forEach { $0.values.forEach { $0.finish() } }
        stateContinuations.values.forEach { $0.finish() }
    }

    // MARK: - Connection intent

    /// Starts connecting to the feed channel and returns without waiting for the join to complete.
    ///
    /// Calling this again with options that resolve to the same socket and channel parameters is a no-op while a
    /// connection is active. Different parameters replace the current connection.
    func connect(options: Knock.FeedClientOptions?) async throws {
        guard !isShutdown else { throw Knock.RealtimeError.disconnected }
        requestGeneration += 1
        let generation = requestGeneration
        intent = .active(options)

        let target: FeedRealtimeTarget
        do {
            target = try await targetProvider(options)
        } catch {
            guard generation == requestGeneration else { return }
            let socket = detachConnection()
            setState(.failed(.connectionFailed(reason: error.localizedDescription)))
            await socket?.disconnect()
            throw error
        }
        guard generation == requestGeneration else { return }

        if let connection, connection.target == target, !state.isFailed {
            return
        }

        let previousSocket = detachConnection()
        let socket: any RealtimeSocket
        do {
            socket = try socketFactory(target.socket)
        } catch {
            setState(.failed(.connectionFailed(reason: error.localizedDescription)))
            await previousSocket?.disconnect()
            throw error
        }

        var connection = Connection(target: target, socket: socket)
        let id = connection.id
        connection.task = Task { await self.runConnection(id: id) }
        self.connection = connection
        setState(.connecting)
        log(.debug, "Connecting to \(target.topic)")
        await previousSocket?.disconnect()
    }

    /// Closes the connection. Event subscriptions stay registered and resume delivering on the next `connect`.
    func disconnect() async {
        requestGeneration += 1
        intent = .idle
        let socket = detachConnection()
        setState(.disconnected)
        await socket?.disconnect()
    }

    /// Closes an active connection but remembers it, so `resume()` can re-establish it (used when the app is backgrounded).
    func suspend() async {
        guard case .active(let options) = intent else { return }
        requestGeneration += 1
        intent = .suspended(options)
        let socket = detachConnection()
        setState(.disconnected)
        await socket?.disconnect()
        log(.debug, "Suspended feed connection")
    }

    /// Re-establishes a suspended connection, or retries a connection that failed. Otherwise does nothing.
    ///
    /// The connection target is rebuilt, so the latest user token and options are used.
    func resume() async throws {
        switch intent {
        case .suspended(let options):
            log(.debug, "Resuming feed connection")
            try await connect(options: options)
        case .active(let options) where state.isFailed:
            log(.debug, "Retrying failed feed connection")
            try await connect(options: options)
        case .active, .idle:
            return
        }
    }

    /// Disconnects and finishes every stream vended by this session. The session cannot be used afterwards.
    func shutdown() async {
        guard !isShutdown else { return }
        await disconnect()
        isShutdown = true
        forwarders.values.forEach { $0.task.cancel() }
        forwarders.removeAll()
        let allSubscribers = subscribers.values.flatMap(\.values)
        subscribers.removeAll()
        allSubscribers.forEach { $0.finish() }
        let allStateContinuations = stateContinuations.values
        stateContinuations.removeAll()
        allStateContinuations.forEach { $0.finish() }
    }

    /// Suspends until the channel is joined. Throws if the connection fails, or if the session is disconnected
    /// before it connects.
    func waitUntilConnected() async throws {
        for await state in connectionStates() {
            switch state {
            case .connected:
                return
            case .failed(let error):
                throw error
            case .disconnected:
                if case .idle = intent {
                    throw Knock.RealtimeError.disconnected
                }
            case .connecting, .reconnecting:
                continue
            }
        }
        try Task.checkCancellation()
        throw Knock.RealtimeError.disconnected
    }

    // MARK: - Streams

    /// The connection state, starting with the current value. Consecutive duplicates are not emitted.
    func connectionStates() -> AsyncStream<Knock.FeedConnectionState> {
        let (stream, continuation) = AsyncStream.makeStream(of: Knock.FeedConnectionState.self, bufferingPolicy: .unbounded)
        continuation.yield(state)
        guard !isShutdown else {
            continuation.finish()
            return stream
        }
        let id = UUID()
        stateContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateContinuation(id: id) }
        }
        return stream
    }

    /// Events named `event` received on the feed channel.
    func events(
        named event: String,
        bufferingPolicy: AsyncStream<Knock.FeedEvent>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Knock.FeedEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: Knock.FeedEvent.self, bufferingPolicy: bufferingPolicy)
        guard !isShutdown else {
            continuation.finish()
            return stream
        }
        let id = UUID()
        subscribers[event, default: [:]][id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(event: event, id: id) }
        }
        startForwarderIfNeeded(event: event)
        return stream
    }

    var subscriberCount: Int {
        subscribers.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Connection lifecycle

    private func runConnection(id: UUID) async {
        guard let socket = connection(id)?.socket else { return }

        // Subscribe before connecting so no transport state is missed.
        let states = await socket.connectionStates()
        guard connection(id) != nil else { return }
        connection?.monitorTask = Self.monitor(states: states, connectionID: id, session: self)

        do {
            try await socket.connect()
        } catch {
            guard connection(id) != nil else { return }
            await fail(connectionID: id, error: .connectionFailed(reason: error.localizedDescription))
            return
        }

        await joinLoop(id: id)
    }

    private func joinLoop(id: UUID) async {
        var attempt = 0
        while let current = connection(id), !Task.isCancelled {
            connection?.joinPhase = .joining
            do {
                let channel = try await current.socket.join(topic: current.target.topic, params: current.target.joinParams)
                guard connection(id) != nil else { return }
                didJoin(channel: channel, connectionID: id)
                return
            } catch RealtimeJoinError.rejected(let reason) {
                guard connection(id) != nil else { return }
                log(.error, "Joining \(current.target.topic) was rejected: \(reason)")
                await fail(connectionID: id, error: .channelJoinRejected(reason: reason))
                return
            } catch {
                guard connection(id) != nil, !Task.isCancelled else { return }
                attempt += 1
                let delay = policy.joinRetryDelay(attempt)
                log(.debug, "Joining \(current.target.topic) failed (\(error.localizedDescription)). Retrying in \(delay)")
                connection?.joinPhase = .waitingToRetry
                try? await Task.sleep(for: delay)
            }
        }
    }

    private func didJoin(channel: any RealtimeChannel, connectionID id: UUID) {
        connection?.channel = channel
        connection?.joinPhase = .joined
        connection?.signalTask?.cancel()
        connection?.signalTask = Self.observeSignals(channel: channel, connectionID: id, session: self)
        setState(.connected)
        log(.debug, "Joined \(channel.topic)")
        for event in subscribers.keys {
            startForwarderIfNeeded(event: event)
        }
    }

    private func restartJoinLoop(connectionID id: UUID) {
        connection?.task?.cancel()
        connection?.task = Task { await self.joinLoop(id: id) }
    }

    private func handleTransportState(_ transportState: RealtimeConnectionState, connectionID id: UUID) async {
        guard let current = connection(id) else { return }
        switch transportState {
        case .idle, .connecting:
            break
        case .connected:
            connection?.hasConnectedTransport = true
            connection?.lastTransportFailure = nil
            // A join that is waiting out its backoff can be retried right away now that the socket is open.
            if current.joinPhase == .waitingToRetry {
                restartJoinLoop(connectionID: id)
            }
            // With a joined channel, the socket rejoins it automatically; `.rejoined` marks the state connected.
        case .reconnecting(let attempt):
            guard current.hasConnectedTransport else {
                if attempt > policy.maxReconnectAttemptsBeforeFirstConnection {
                    let reason = current.lastTransportFailure ?? "The socket did not connect after \(attempt - 1) attempts"
                    log(.error, "Giving up on the feed socket: \(reason)")
                    await fail(connectionID: id, error: .connectionFailed(reason: reason))
                }
                // Still establishing the first connection.
                return
            }
            setState(.reconnecting(attempt: attempt))
        case .disconnected(let code, let reason):
            connection?.lastTransportFailure = "Socket closed with code \(code)" + (reason.map { ": \($0)" } ?? "")
        case .failed(let reason):
            connection?.lastTransportFailure = reason
        }
    }

    private func handleSignal(_ signal: RealtimeChannelSignal, connectionID id: UUID) async {
        guard connection(id) != nil else { return }
        switch signal {
        case .rejoined:
            setState(.connected)
        case .errored:
            // The server-side channel crashed. The socket is still up, so join the channel again.
            log(.error, "The feed channel errored. Rejoining.")
            connection?.channel = nil
            connection?.signalTask?.cancel()
            connection?.signalTask = nil
            setState(.reconnecting(attempt: 1))
            restartJoinLoop(connectionID: id)
        case .closed:
            log(.error, "The feed channel was closed by the server")
            await fail(connectionID: id, error: .channelClosed)
        case .rejoinRejected(let reason):
            log(.error, "Rejoining the feed channel was rejected: \(reason)")
            await fail(connectionID: id, error: .channelJoinRejected(reason: reason))
        }
    }

    private func fail(connectionID id: UUID, error: Knock.RealtimeError) async {
        guard connection(id) != nil else { return }
        let socket = detachConnection()
        setState(.failed(error))
        await socket?.disconnect()
    }

    /// Stops the current connection's tasks and returns its socket, which the caller must disconnect.
    private func detachConnection() -> (any RealtimeSocket)? {
        guard let current = connection else { return nil }
        connection = nil
        current.cancelTasks()
        forwarders.values.forEach { $0.task.cancel() }
        forwarders.removeAll()
        return current.socket
    }

    private func connection(_ id: UUID) -> Connection? {
        guard let connection, connection.id == id else { return nil }
        return connection
    }

    private func setState(_ newState: Knock.FeedConnectionState) {
        guard newState != state else { return }
        state = newState
        stateContinuations.values.forEach { $0.yield(newState) }
    }

    private func removeStateContinuation(id: UUID) {
        stateContinuations[id] = nil
    }

    // MARK: - Event forwarding

    private func startForwarderIfNeeded(event: String) {
        guard forwarders[event] == nil,
              subscribers[event]?.isEmpty == false,
              let channel = connection?.channel
        else { return }
        let id = UUID()
        let task = Self.forward(event: event, channel: channel, forwarderID: id, session: self)
        forwarders[event] = Forwarder(id: id, task: task)
    }

    private func deliver(_ feedEvent: Knock.FeedEvent) {
        // Events only arrive on a joined channel, so they also confirm a rejoin that wasn't otherwise observed.
        if connection?.channel != nil {
            setState(.connected)
        }
        subscribers[feedEvent.event]?.values.forEach { $0.yield(feedEvent) }
    }

    /// The channel's message stream ends whenever the socket drops. Subscribe again so events keep flowing after
    /// the socket reconnects and rejoins.
    private func forwarderEnded(event: String, forwarderID: UUID) {
        guard forwarders[event]?.id == forwarderID else { return }
        forwarders[event] = nil
        startForwarderIfNeeded(event: event)
    }

    private func removeSubscriber(event: String, id: UUID) {
        subscribers[event]?[id] = nil
        guard subscribers[event]?.isEmpty ?? true else { return }
        subscribers[event] = nil
        forwarders.removeValue(forKey: event)?.task.cancel()
    }

    private func logStreamFailure(event: String, error: Error) {
        log(.error, "The \(event) event stream failed: \(error.localizedDescription)")
    }

    // MARK: - Tasks
    //
    // These tasks hold the session weakly so that dropping the session tears the connection down.

    private nonisolated static func monitor(
        states: AsyncStream<RealtimeConnectionState>,
        connectionID: UUID,
        session: FeedRealtimeSession
    ) -> Task<Void, Never> {
        Task { [weak session] in
            for await state in states {
                guard let session else { return }
                await session.handleTransportState(state, connectionID: connectionID)
            }
        }
    }

    private nonisolated static func observeSignals(
        channel: any RealtimeChannel,
        connectionID: UUID,
        session: FeedRealtimeSession
    ) -> Task<Void, Never> {
        Task { [weak session] in
            let signals = await channel.signals()
            for await signal in signals {
                guard let session else { return }
                await session.handleSignal(signal, connectionID: connectionID)
            }
        }
    }

    private nonisolated static func forward(
        event: String,
        channel: any RealtimeChannel,
        forwarderID: UUID,
        session: FeedRealtimeSession
    ) -> Task<Void, Never> {
        Task { [weak session] in
            let messages = await channel.messages(event: event)
            do {
                for try await payload in messages {
                    guard let session else { return }
                    await session.deliver(Knock.FeedEvent(event: event, topic: channel.topic, payload: payload))
                }
            } catch {
                await session?.logStreamFailure(event: event, error: error)
            }
            guard !Task.isCancelled else { return }
            await session?.forwarderEnded(event: event, forwarderID: forwarderID)
        }
    }
}

extension Knock.FeedConnectionState {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
