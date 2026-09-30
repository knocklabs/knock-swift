//
//  FeedManagerRealtimeTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("FeedManager realtime")
struct FeedManagerRealtimeTests {
    let factory = FakeRealtimeSocketFactory()
    let environment = KnockEnvironment()
    let lifecycle = AsyncStream.makeStream(of: AppLifecycleEvent.self)

    init() async throws {
        try await environment.setPublishableKey(key: "pk_test")
        await environment.setUserInfo(userId: "user-1", userToken: "token-1")
    }

    func makeManager(options: Knock.FeedClientOptions = Knock.FeedClientOptions(archived: .exclude)) -> Knock.FeedManager {
        let environment = environment
        let module = FeedModule(
            feedId: "feed-1",
            options: options,
            environment: { environment },
            socketFactory: factory.make,
            realtimePolicy: .fast
        )
        return Knock.FeedManager(feedModule: module, lifecycleEvents: lifecycle.stream)
    }

    @Test func connectBuildsTheTargetFromTheEnvironment() async throws {
        await environment.setBaseUrl(baseUrl: "http://localhost:4000/")
        let manager = makeManager(options: Knock.FeedClientOptions(tenant: "acme", archived: .exclude))

        try await withTimeout { try await manager.connect(options: Knock.FeedClientOptions(has_tenant: true)) }

        let socket = try #require(factory.last)
        #expect(socket.configuration.endpoint == "ws://localhost:4000/ws/v1/websocket")
        #expect(socket.configuration.connectParams == ["api_key": "pk_test", "user_token": "token-1"])
        #expect(socket.joinRequests.first?.topic == "feeds:feed-1:user-1")
        #expect(socket.joinRequests.first?.params?.tenant == "acme")
        #expect(socket.joinRequests.first?.params?.has_tenant == true)
        #expect(await manager.connectionState == .connected)
        #expect(manager.feedId == "feed-1")
    }

    @Test func connectFailsWhenNoUserIsSignedIn() async throws {
        await environment.setUserInfo(userId: nil, userToken: nil)
        let manager = makeManager()

        await #expect(throws: Knock.KnockError.userIdNotSetError) {
            try await manager.connect()
        }
        #expect(factory.created.isEmpty)
    }

    @Test func connectAndDisconnectAreAppliedInOrder() async throws {
        let manager = makeManager()

        manager.connectToFeed()
        manager.disconnectFromFeed()
        manager.connectToFeed(options: Knock.FeedClientOptions(tenant: "b"))
        manager.disconnectFromFeed()
        await manager.disconnect()

        #expect(await manager.connectionState == .disconnected)
        #expect(factory.created.count == 2)
        #expect(factory.created.allSatisfy { $0.disconnectCount == 1 })
    }

    @Test func onDeliversEventsOnTheMainActorUntilCancelled() async throws {
        let manager = makeManager()
        let received = LockIsolated<[Knock.FeedEvent]>([])
        let subscription = manager.on(eventName: "new-message") { event in
            MainActor.assertIsolated()
            received.withLock { $0.append(event) }
        }
        try await withTimeout { try await manager.connect() }
        let channel = try #require(factory.last?.lastChannel)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }

        channel.push("new-message", ["feed_id": "feed-1"])
        try await waitUntil("delivery") { received.value.count == 1 }
        #expect(received.value.first?.payload == ["feed_id": "feed-1"])

        subscription.cancel()
        #expect(subscription.isCancelled)
        try await waitUntil("unsubscribed") { channel.liveSubscriptionCount(for: "new-message") == 0 }
        channel.push("new-message")
        try await expectStaysTrue("no delivery after cancelling") { received.value.count == 1 }
    }

    @Test func eventsCanBeSubscribedBeforeConnecting() async throws {
        let manager = makeManager()
        let events = StreamRecorder(await manager.events(named: "new-message"))

        try await withTimeout { try await manager.connect() }
        let channel = try #require(factory.last?.lastChannel)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }
        channel.push("new-message")

        try await waitUntil("delivery") { events.values.count == 1 }
    }

    @Test func backgroundingSuspendsAndForegroundingResumes() async throws {
        let manager = makeManager()
        let events = StreamRecorder(await manager.events(named: "new-message"))
        try await withTimeout { try await manager.connect() }
        let first = try #require(factory.last)

        lifecycle.continuation.yield(.didEnterBackground)
        try await waitUntil("suspended") { first.disconnectCount == 1 }
        #expect(await manager.connectionState == .disconnected)

        await environment.setUserInfo(userId: "user-1", userToken: "token-2")
        lifecycle.continuation.yield(.didBecomeActive)
        try await waitUntil("resumed") { await manager.connectionState == .connected }

        let second = try #require(factory.last)
        #expect(second !== first)
        #expect(second.configuration.connectParams["user_token"] == "token-2", "Resuming picks up a refreshed user token")
        let channel = try #require(second.lastChannel)
        try await waitUntil("subscription") { channel.liveSubscriptionCount(for: "new-message") == 1 }
        channel.push("new-message")
        try await waitUntil("delivery") { events.values.count == 1 }
    }

    @Test func foregroundingDoesNotConnectAFeedThatWasNeverConnected() async throws {
        let manager = makeManager()

        lifecycle.continuation.yield(.didEnterBackground)
        lifecycle.continuation.yield(.didBecomeActive)
        await manager.disconnect()

        #expect(factory.created.isEmpty)
    }

    @Test func foregroundingDoesNotReconnectAFeedThatWasDisconnected() async throws {
        let manager = makeManager()
        try await withTimeout { try await manager.connect() }
        await manager.disconnect()

        lifecycle.continuation.yield(.didEnterBackground)
        lifecycle.continuation.yield(.didBecomeActive)
        await manager.disconnect()

        #expect(factory.created.count == 1)
    }

    @Test func connectionStatesAreObservable() async throws {
        let manager = makeManager()
        let states = StreamRecorder(await manager.connectionStates())

        try await withTimeout { try await manager.connect() }
        await manager.disconnect()

        try await states.waitFor(.disconnected)
        #expect(states.values == [.disconnected, .connecting, .connected, .disconnected])
    }

    @Test func releasingTheManagerShutsTheConnectionDown() async throws {
        var manager: Knock.FeedManager? = makeManager()
        let events = StreamRecorder(await manager!.events(named: "new-message"))
        try await withTimeout { [manager] in try await manager?.connect() }
        let socket = try #require(factory.last)

        manager = nil

        try await waitUntil("socket disconnected") { socket.disconnectCount == 1 }
        try await waitUntil("event stream finished") { events.isFinished }
    }
}
