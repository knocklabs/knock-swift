//
//  FeedRealtimeSessionTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("FeedRealtimeSession")
struct FeedRealtimeSessionTests {
    let factory = FakeRealtimeSocketFactory()

    func makeSession(
        policy: FeedRealtimeSession.Policy = .fast,
        targetProvider: FeedRealtimeSession.TargetProvider? = nil
    ) -> FeedRealtimeSession {
        FeedRealtimeSession(
            socketFactory: factory.make,
            targetProvider: targetProvider ?? { options in .fixture(options: options) },
            policy: policy
        )
    }

    func connected(_ session: FeedRealtimeSession, options: Knock.FeedClientOptions? = nil) async throws -> FakeRealtimeChannel {
        try await session.connect(options: options)
        try await withTimeout { try await session.waitUntilConnected() }
        let channel = try #require(factory.last?.lastChannel)
        try await waitUntil("signal subscription") { channel.signalSubscriberCount == 1 }
        return channel
    }

    // MARK: Connecting

    @Test func connectJoinsTheFeedChannel() async throws {
        let session = makeSession()
        let states = StreamRecorder(await session.connectionStates())

        _ = try await connected(session, options: Knock.FeedClientOptions(tenant: "acme"))

        let socket = try #require(factory.last)
        #expect(factory.created.count == 1)
        #expect(socket.connectCount == 1)
        #expect(socket.configuration.endpoint == "wss://api.knock.app/ws/v1/websocket")
        #expect(socket.configuration.connectParams == ["api_key": "pk_test", "user_token": "token"])
        #expect(socket.joinRequests.map(\.topic) == ["feeds:feed-1:user-1"])
        #expect(socket.joinRequests.first?.params?.tenant == "acme")
        #expect(socket.joinRequests.first?.params?.archived == "exclude")
        try await states.waitFor(.connected)
        #expect(states.values == [.disconnected, .connecting, .connected])
        #expect(await session.state == .connected)
    }

    @Test func connectingAgainWithTheSameTargetIsANoOp() async throws {
        let session = makeSession()
        _ = try await connected(session)

        try await session.connect(options: nil)
        try await session.connect(options: Knock.FeedClientOptions(archived: .exclude))

        #expect(factory.created.count == 1)
        #expect(factory.last?.joinRequests.count == 1)
        #expect(await session.state == .connected)
    }

    @Test func connectingWithDifferentOptionsReplacesTheConnection() async throws {
        let session = makeSession()
        _ = try await connected(session, options: Knock.FeedClientOptions(tenant: "a"))
        let first = try #require(factory.last)

        _ = try await connected(session, options: Knock.FeedClientOptions(tenant: "b"))

        #expect(factory.created.count == 2)
        #expect(first.disconnectCount == 1)
        #expect(factory.last?.joinRequests.first?.params?.tenant == "b")
    }

    @Test func aChangedUserTokenReplacesTheConnection() async throws {
        let token = LockIsolated("first")
        let session = makeSession(targetProvider: { options in .fixture(options: options, userToken: token.value) })
        _ = try await connected(session)

        token.setValue("second")
        _ = try await connected(session)

        #expect(factory.created.map { $0.configuration.connectParams["user_token"] } == ["first", "second"])
        #expect(factory.created.first?.disconnectCount == 1)
    }

    @Test func targetProviderFailureFailsTheConnection() async throws {
        let session = makeSession(targetProvider: { _ in throw Knock.KnockError.userIdNotSetError })

        await #expect(throws: Knock.KnockError.userIdNotSetError) {
            try await session.connect(options: nil)
        }
        #expect(factory.created.isEmpty)
        guard case .failed(.connectionFailed) = await session.state else {
            Issue.record("Expected a connectionFailed state, got \(await session.state)")
            return
        }
    }

    @Test func socketFactoryFailureFailsTheConnection() async throws {
        let session = makeSession()
        factory.failNextCreation(with: "bad endpoint")

        await #expect(throws: TestError(reason: "bad endpoint")) {
            try await session.connect(options: nil)
        }
        guard case .failed(.connectionFailed) = await session.state else {
            Issue.record("Expected a connectionFailed state, got \(await session.state)")
            return
        }

        _ = try await connected(session)
    }

    @Test func socketConnectFailureFailsTheConnection() async throws {
        let session = makeSession()
        factory.onCreate { $0.failConnect(with: "offline") }

        try await session.connect(options: nil)

        await #expect(throws: Knock.RealtimeError.connectionFailed(reason: "offline")) {
            try await withTimeout { try await session.waitUntilConnected() }
        }
        #expect(factory.last?.disconnectCount == 1)
    }

    // MARK: Joining

    @Test func transientJoinFailuresAreRetried() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.fail("timeout"), .fail("timeout")) }

        _ = try await connected(session)

        #expect(factory.last?.joinRequests.count == 3)
        #expect(factory.created.count == 1)
    }

    @Test func rejectedJoinFailsTheConnection() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.reject("unauthorized")) }

        try await session.connect(options: nil)

        await #expect(throws: Knock.RealtimeError.channelJoinRejected(reason: "unauthorized")) {
            try await withTimeout { try await session.waitUntilConnected() }
        }
        #expect(await session.state == .failed(.channelJoinRejected(reason: "unauthorized")))
        #expect(factory.last?.joinRequests.count == 1)
        #expect(factory.last?.disconnectCount == 1)
    }

    @Test func anUnrecoverableJoinFailureFailsTheConnectionWithoutRetrying() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.failUnrecoverably("Encoding failed")) }

        try await session.connect(options: nil)

        await #expect(throws: Knock.RealtimeError.connectionFailed(reason: "Encoding failed")) {
            try await withTimeout { try await session.waitUntilConnected() }
        }
        #expect(factory.last?.joinRequests.count == 1)
        #expect(factory.last?.disconnectCount == 1)
    }

    @Test func connectingAfterAFailureStartsANewConnection() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.reject("unauthorized")) }
        try await session.connect(options: nil)
        try await waitUntil("failed state") { await session.state.isFailed }

        factory.onCreate { _ in }
        _ = try await connected(session)

        #expect(factory.created.count == 2)
    }

    @Test func aJoinWaitingToRetryIsRetriedAsSoonAsTheSocketOpens() async throws {
        let session = makeSession(policy: .init(joinRetryDelay: { _ in .seconds(600) }, maxReconnectAttemptsBeforeFirstConnection: 3))
        factory.onCreate { $0.enqueueJoins(.fail("not connected")) }

        try await session.connect(options: nil)
        let socket = try #require(factory.last)
        try await waitUntil("join waiting to retry") { await session.isWaitingToRetryJoin }

        socket.emit(.connected)

        try await withTimeout { try await session.waitUntilConnected() }
        #expect(socket.joinRequests.count == 2)
    }

    // MARK: Transport

    @Test func givesUpWhenTheSocketNeverConnects() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.hang) }
        try await session.connect(options: nil)
        let socket = try #require(factory.last)
        try await waitUntil("state subscription") { socket.stateSubscriberCount > 0 }

        socket.emit(.failed(reason: "HTTP 401"))
        for attempt in 1...3 {
            socket.emit(.reconnecting(attempt: attempt))
        }
        // Transport states are handled in order, so giving up after attempt 3 would report this earlier failure.
        socket.emit(.failed(reason: "HTTP 403"))
        socket.emit(.reconnecting(attempt: 4))

        try await waitUntil("failed state") { await session.state.isFailed }
        #expect(await session.state == .failed(.connectionFailed(reason: "HTTP 403")))
        #expect(socket.disconnectCount == 1)
    }

    @Test func reconnectsIndefinitelyOnceConnected() async throws {
        let session = makeSession()
        let channel = try await connected(session)
        let socket = try #require(factory.last)
        socket.emit(.connected)

        for attempt in 1...10 {
            socket.emit(.reconnecting(attempt: attempt))
        }
        try await waitUntil("reconnecting state") { await session.state == .reconnecting(attempt: 10) }
        let states = StreamRecorder(await session.connectionStates())

        socket.emit(.connected)
        socket.emit(.reconnecting(attempt: 11))
        try await states.waitFor(.reconnecting(attempt: 11))
        #expect(!states.values.contains(.connected), "Connected is only reported once the channel is rejoined")

        channel.send(.rejoined)
        try await waitUntil("connected state") { await session.state == .connected }
        #expect(socket.disconnectCount == 0)
    }

    @Test func anEventMarksARejoinedChannelConnected() async throws {
        let session = makeSession()
        let channel = try await connected(session)
        let socket = try #require(factory.last)
        let events = StreamRecorder(await session.events(named: "new-message"))
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        socket.emit(.connected)
        socket.emit(.reconnecting(attempt: 1))
        try await waitUntil("reconnecting state") { await session.state == .reconnecting(attempt: 1) }

        channel.push("new-message")

        try await waitUntil("connected state") { await session.state == .connected }
        try await waitUntil("event") { events.values.count == 1 }
    }

    // MARK: Channel signals

    @Test func anErroredChannelIsRejoined() async throws {
        let session = makeSession()
        let channel = try await connected(session)
        let socket = try #require(factory.last)

        channel.send(.errored)

        try await waitUntil("rejoin") { socket.joinRequests.count == 2 }
        try await waitUntil("connected state") { await session.state == .connected }
        #expect(socket.disconnectCount == 0)
    }

    @Test func eventsKeepFlowingAfterAnErroredChannelIsRejoined() async throws {
        let session = makeSession()
        let channel = try await connected(session)
        let socket = try #require(factory.last)
        let events = StreamRecorder(await session.events(named: "new-message"))
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        channel.send(.errored)
        try await waitUntil("rejoin") { socket.channels.count == 2 }
        let rejoined = try #require(socket.lastChannel)
        try await waitUntil("resubscription") { rejoined.liveSubscriptionCount(for: "new-message") == 1 }
        try await waitUntil("old subscription cancelled") { channel.liveSubscriptionCount(for: "new-message") == 0 }
        #expect(channel.signalSubscriberCount == 1)

        rejoined.push("new-message", ["id": "1"])

        try await waitUntil("event") { events.values.count == 1 }
    }

    @Test func aChannelThatKeepsErroringIsRejoinedWithBackoff() async throws {
        let delays = LockIsolated<[Int]>([])
        let session = makeSession(policy: .init(
            joinRetryDelay: { attempt in
                delays.withLock { $0.append(attempt) }
                return .milliseconds(10)
            },
            maxReconnectAttemptsBeforeFirstConnection: 3
        ))
        let events = StreamRecorder(await session.events(named: "new-message"))
        let first = try await connected(session)
        let socket = try #require(factory.last)

        first.send(.errored)
        try await waitUntil("first rejoin") { socket.channels.count == 2 }
        #expect(delays.value == [1])
        let second = try #require(socket.lastChannel)
        try await waitUntil("signal subscription") { second.signalSubscriberCount == 1 }
        second.send(.errored)
        try await waitUntil("second rejoin") { socket.channels.count == 3 }
        #expect(delays.value == [1, 2])

        let third = try #require(socket.lastChannel)
        try await waitUntil("subscriptions") { third.liveSubscriptionCount(for: "new-message") == 1 && third.signalSubscriberCount == 1 }
        third.push("new-message")
        try await waitUntil("event") { events.values.count == 1 }
        third.send(.errored)
        try await waitUntil("third rejoin") { socket.channels.count == 4 }
        #expect(delays.value == [1, 2, 1], "An event shows the channel recovered, so the backoff starts over")
    }

    @Test func aClosedChannelFailsTheConnection() async throws {
        let session = makeSession()
        let channel = try await connected(session)

        channel.send(.closed)

        try await waitUntil("failed state") { await session.state == .failed(.channelClosed) }
        #expect(factory.last?.disconnectCount == 1)
    }

    @Test func aRejectedRejoinFailsTheConnection() async throws {
        let session = makeSession()
        let channel = try await connected(session)

        channel.send(.rejoinRejected(reason: "token expired"))

        try await waitUntil("failed state") { await session.state == .failed(.channelJoinRejected(reason: "token expired")) }
        #expect(factory.last?.disconnectCount == 1)
    }

    // MARK: Events

    @Test func eventsAreDeliveredToEverySubscriber() async throws {
        let session = makeSession()
        let first = StreamRecorder(await session.events(named: "new-message"))
        let second = StreamRecorder(await session.events(named: "new-message"))
        let other = StreamRecorder(await session.events(named: "other"))
        let channel = try await connected(session)
        try await waitUntil("subscriptions") {
            channel.liveSubscriptionCount(for: "new-message") == 1 && channel.liveSubscriptionCount(for: "other") == 1
        }

        channel.push("new-message", ["feed_id": "feed-1"])

        try await waitUntil("delivery") { first.values.count == 1 && second.values.count == 1 }
        let expected = Knock.FeedEvent(event: "new-message", topic: "feeds:feed-1:user-1", payload: ["feed_id": "feed-1"])
        #expect(first.values == [expected])
        #expect(second.values == [expected])
        #expect(other.values.isEmpty)
        #expect(channel.subscribeCount(for: "new-message") == 1, "Subscribers share one channel subscription")
    }

    @Test func eventsArriveInOrder() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        let channel = try await connected(session)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        for index in 0..<50 {
            channel.push("new-message", ["index": AnyCodable(index)])
        }

        try await waitUntil("delivery") { events.values.count == 50 }
        #expect(events.values.map { $0.payload["index"]?.value as? Int } == Array(0..<50))
    }

    @Test func cancellingTheLastSubscriberStopsTheChannelSubscription() async throws {
        let session = makeSession()
        let channel = try await connected(session)
        let first = StreamRecorder(await session.events(named: "new-message"))
        let second = StreamRecorder(await session.events(named: "new-message"))
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        first.cancel()
        try await waitUntil("subscriber removed") { await session.subscriberCount == 1 }
        #expect(channel.liveSubscriptionCount(for: "new-message") == 1)

        channel.push("new-message")
        try await waitUntil("delivery") { second.values.count == 1 }
        #expect(first.values.isEmpty)

        second.cancel()
        try await waitUntil("channel subscription cancelled") { channel.liveSubscriptionCount(for: "new-message") == 0 }
        #expect(await session.subscriberCount == 0)
    }

    @Test func subscriptionsResumeAfterTheChannelStreamEnds() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        let channel = try await connected(session)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        channel.finishMessageStreams()
        try await waitUntil("resubscription") {
            channel.subscribeCount(for: "new-message") == 2 && channel.liveSubscriptionCount(for: "new-message") == 1
        }
        channel.push("new-message")

        try await waitUntil("delivery") { events.values.count == 1 }
    }

    @Test func subscriptionsResumeAfterAStreamError() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        let channel = try await connected(session)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        channel.failMessages("new-message", error: TimeoutError(description: "decoding"))
        try await waitUntil("resubscription") { channel.subscribeCount(for: "new-message") == 2 }
        try await waitUntil("live subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }
        channel.push("new-message")

        try await waitUntil("delivery") { events.values.count == 1 }
    }

    @Test func subscriptionsSurviveDisconnectAndReconnect() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        _ = try await connected(session)

        await session.disconnect()
        #expect(!events.isFinished)

        let channel = try await connected(session)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }
        channel.push("new-message")

        try await waitUntil("delivery") { events.values.count == 1 }
        #expect(factory.created.count == 2)
    }

    // MARK: Disconnecting

    @Test func disconnectClosesTheSocket() async throws {
        let session = makeSession()
        _ = try await connected(session)

        await session.disconnect()

        #expect(await session.state == .disconnected)
        #expect(factory.last?.disconnectCount == 1)
    }

    @Test func disconnectWhileTheTargetIsResolvingCancelsTheConnect() async throws {
        let gate = AsyncGate()
        let session = makeSession(targetProvider: { options in
            await gate.wait()
            return .fixture(options: options)
        })

        let connect = Task { try await session.connect(options: nil) }
        try await waitUntil("provider called") { await gate.waiterCount == 1 }
        await session.disconnect()
        await gate.open()
        try await connect.value

        #expect(factory.created.isEmpty)
        #expect(await session.state == .disconnected)
    }

    @Test func waitUntilConnectedThrowsWhenDisconnected() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.hang) }
        try await session.connect(options: nil)

        let wait = Task { try await session.waitUntilConnected() }
        await session.disconnect()

        await #expect(throws: Knock.RealtimeError.disconnected) {
            try await withTimeout { try await wait.value }
        }
    }

    @Test func waitUntilConnectedHonorsCancellation() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.hang) }
        try await session.connect(options: nil)

        let wait = Task { try await session.waitUntilConnected() }
        wait.cancel()

        await #expect(throws: CancellationError.self) {
            try await withTimeout { try await wait.value }
        }
    }

    @Test func disconnectCancelsAHangingJoin() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.hang) }
        try await session.connect(options: nil)
        let socket = try #require(factory.last)
        try await waitUntil("join attempt") { socket.joinRequests.count == 1 }

        await session.disconnect()

        try await expectStaysTrue("no further joins") { socket.joinRequests.count == 1 && socket.channels.isEmpty }
    }

    // MARK: Suspend and resume

    @Test func suspendAndResumeReconnect() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        _ = try await connected(session, options: Knock.FeedClientOptions(tenant: "acme"))

        await session.suspend()
        #expect(await session.state == .disconnected)
        #expect(factory.last?.disconnectCount == 1)

        try await session.resume()
        try await withTimeout { try await session.waitUntilConnected() }
        let channel = try #require(factory.last?.lastChannel)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }
        channel.push("new-message")

        try await waitUntil("delivery") { events.values.count == 1 }
        #expect(factory.created.count == 2)
        #expect(factory.last?.joinRequests.first?.params?.tenant == "acme")
    }

    @Test func resumeDoesNothingWhenNotSuspended() async throws {
        let session = makeSession()
        try await session.resume()
        #expect(factory.created.isEmpty)

        _ = try await connected(session)
        try await session.resume()
        #expect(factory.created.count == 1)

        await session.disconnect()
        try await session.resume()
        #expect(factory.created.count == 1)
    }

    @Test func suspendDoesNothingWhenIdle() async throws {
        let session = makeSession()
        await session.suspend()
        try await session.resume()
        #expect(factory.created.isEmpty)
    }

    @Test func resumeRetriesAFailedConnection() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.reject("unauthorized")) }
        try await session.connect(options: nil)
        try await waitUntil("failed state") { await session.state.isFailed }

        factory.onCreate { _ in }
        try await session.resume()

        try await withTimeout { try await session.waitUntilConnected() }
        #expect(factory.created.count == 2)
    }

    @Test func waitUntilConnectedThrowsWhenASuspendedConnectionIsDisconnected() async throws {
        let session = makeSession()
        _ = try await connected(session)
        await session.suspend()

        let finished = LockIsolated(false)
        let wait = Task {
            defer { finished.setValue(true) }
            try await session.waitUntilConnected()
        }
        try await expectStaysTrue("waiting while suspended") { !finished.value }
        await session.disconnect()

        await #expect(throws: Knock.RealtimeError.disconnected) {
            try await withTimeout { try await wait.value }
        }
    }

    @Test func retryIfFailedRetriesOnlyFailedConnections() async throws {
        let session = makeSession()
        factory.onCreate { $0.enqueueJoins(.reject("unauthorized")) }
        try await session.connect(options: nil)
        try await waitUntil("failed state") { await session.state.isFailed }

        factory.onCreate { _ in }
        try await session.retryIfFailed()
        try await withTimeout { try await session.waitUntilConnected() }
        #expect(factory.created.count == 2)

        try await session.retryIfFailed()
        await session.suspend()
        try await session.retryIfFailed()
        #expect(factory.created.count == 2)
        #expect(await session.state == .disconnected)
    }

    @Test func waitUntilConnectedKeepsWaitingWhileSuspended() async throws {
        let session = makeSession()
        _ = try await connected(session)
        await session.suspend()

        let finished = LockIsolated(false)
        let wait = Task {
            try await session.waitUntilConnected()
            finished.setValue(true)
        }
        try await expectStaysTrue("waiting while suspended") { !finished.value }
        try await session.resume()

        try await withTimeout { try await wait.value }
        #expect(finished.value)
    }

    // MARK: Shutdown and state stream

    @Test func shutdownFinishesEveryStream() async throws {
        let session = makeSession()
        let events = StreamRecorder(await session.events(named: "new-message"))
        let states = StreamRecorder(await session.connectionStates())
        _ = try await connected(session)

        await session.shutdown()

        try await waitUntil("streams finished") { events.isFinished && states.isFinished }
        #expect(factory.last?.disconnectCount == 1)
        await #expect(throws: Knock.RealtimeError.disconnected) {
            try await session.connect(options: nil)
        }
        let late = StreamRecorder(await session.events(named: "new-message"))
        try await waitUntil("late stream finished") { late.isFinished }
    }

    @Test func connectionStatesStartWithTheCurrentStateAndSkipDuplicates() async throws {
        let session = makeSession()
        _ = try await connected(session)

        let states = StreamRecorder(await session.connectionStates())
        try await waitUntil("initial state") { states.values == [.connected] }

        let socket = try #require(factory.last)
        socket.emit(.connected)
        socket.emit(.reconnecting(attempt: 1))
        socket.emit(.reconnecting(attempt: 1))
        socket.emit(.reconnecting(attempt: 2))
        try await states.waitFor(.reconnecting(attempt: 2))

        #expect(states.values == [.connected, .reconnecting(attempt: 1), .reconnecting(attempt: 2)])
    }

    @Test func releasingTheSessionDisconnectsTheSocket() async throws {
        var session: FeedRealtimeSession? = makeSession()
        _ = try await connected(session!)
        let socket = try #require(factory.last)

        await session?.suspend()
        try await session?.resume()
        try await waitUntil("reconnected") { await session?.state == .connected }
        let current = try #require(factory.last)
        #expect(current !== socket)

        session = nil

        try await waitUntil("socket disconnected") { current.disconnectCount == 1 }
    }
}
