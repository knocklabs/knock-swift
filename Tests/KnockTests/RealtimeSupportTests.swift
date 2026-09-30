//
//  RealtimeSupportTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("FeedRealtimeTarget")
struct FeedRealtimeTargetTests {
    @Test(arguments: [
        ("https://api.knock.app", "wss://api.knock.app/ws/v1/websocket"),
        ("https://api.knock.app/", "wss://api.knock.app/ws/v1/websocket"),
        ("http://localhost:4000", "ws://localhost:4000/ws/v1/websocket"),
        ("HTTPS://eu.knock.app", "wss://eu.knock.app/ws/v1/websocket"),
        ("https://proxy.example.com/knock-http", "wss://proxy.example.com/knock-http/ws/v1/websocket"),
    ])
    func websocketEndpoint(baseUrl: String, expected: String) {
        #expect(FeedRealtimeTarget.websocketEndpoint(baseUrl: baseUrl) == expected)
    }

    @Test func targetUsesTheFeedTopicAndConnectParams() {
        let target = FeedRealtimeTarget.make(
            baseUrl: "https://api.knock.app",
            publishableKey: "pk_test",
            userToken: nil,
            userId: "user-1",
            feedId: "feed-1",
            options: Knock.FeedClientOptions()
        )

        #expect(target.topic == "feeds:feed-1:user-1")
        #expect(target.socket.connectParams == ["api_key": "pk_test", "user_token": ""])
    }

    @Test func joinParamsIncludeEveryFilter() throws {
        let options = Knock.FeedClientOptions(
            before: "cursor-b",
            after: "cursor-a",
            page_size: 25,
            status: .unread,
            source: "workflow",
            tenant: "acme",
            has_tenant: true,
            archived: .include,
            trigger_data: ["plan": "pro", "seats": 3],
            locale: "en"
        )

        let json = try jsonObject(FeedChannelJoinParams(options: options))

        #expect(json["before"] as? String == "cursor-b")
        #expect(json["after"] as? String == "cursor-a")
        #expect(json["page_size"] as? Int == 25)
        #expect(json["status"] as? String == "unread")
        #expect(json["source"] as? String == "workflow")
        #expect(json["tenant"] as? String == "acme")
        #expect(json["has_tenant"] as? Bool == true)
        #expect(json["archived"] as? String == "include")
        let triggerData = try #require(json["trigger_data"] as? [String: Any])
        #expect(triggerData["plan"] as? String == "pro")
        #expect(triggerData["seats"] as? Int == 3)
        #expect(json["locale"] == nil, "Locale only applies to feed HTTP requests")
    }

    @Test func joinParamsOmitUnsetFilters() throws {
        let json = try jsonObject(FeedChannelJoinParams(options: Knock.FeedClientOptions(archived: .exclude)))
        #expect(json.keys.sorted() == ["archived"])
    }

    @Test func targetsWithDifferentOptionsAreNotEqual() {
        #expect(FeedRealtimeTarget.fixture() == FeedRealtimeTarget.fixture())
        #expect(FeedRealtimeTarget.fixture() != FeedRealtimeTarget.fixture(options: Knock.FeedClientOptions(tenant: "acme")))
        #expect(FeedRealtimeTarget.fixture() != FeedRealtimeTarget.fixture(options: Knock.FeedClientOptions(trigger_data: ["a": 1])))
        #expect(FeedRealtimeTarget.fixture() != FeedRealtimeTarget.fixture(userToken: "other"))
    }

    private func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

@Suite("FeedEvent")
struct FeedEventTests {
    struct NewMessage: Decodable, Equatable {
        let feed_id: String
        let metadata: Metadata

        struct Metadata: Decodable, Equatable {
            let unread_count: Int
        }
    }

    @Test func decodesThePayload() throws {
        let event = Knock.FeedEvent(
            event: "new-message",
            topic: "feeds:feed-1:user-1",
            payload: ["feed_id": "feed-1", "metadata": ["unread_count": 3]]
        )

        let decoded = try event.decodePayload(as: NewMessage.self)

        #expect(decoded == NewMessage(feed_id: "feed-1", metadata: .init(unread_count: 3)))
    }

    @Test func decodingAMismatchedPayloadThrows() {
        let event = Knock.FeedEvent(event: "new-message", topic: "t", payload: ["feed_id": 1])
        #expect(throws: DecodingError.self) {
            try event.decodePayload(as: NewMessage.self)
        }
    }

    @Test func subscriptionCancelsItsTask() async {
        let task = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        let subscription = Knock.FeedEventSubscription(task: task)
        #expect(!subscription.isCancelled)

        subscription.cancel()

        #expect(subscription.isCancelled)
        #expect(task.isCancelled)
    }
}

@Suite("SerialExecutionQueue")
struct SerialExecutionQueueTests {
    @Test func runsOperationsOneAtATimeInOrder() async throws {
        let queue = SerialExecutionQueue()
        let log = LockIsolated<[String]>([])

        for index in 0..<20 {
            queue.enqueue {
                log.withLock { $0.append("start \(index)") }
                await Task.yield()
                log.withLock { $0.append("end \(index)") }
            }
        }
        try await queue.run { }

        #expect(log.value == (0..<20).flatMap { ["start \($0)", "end \($0)"] })
    }

    @Test func runReturnsTheResultAndPropagatesErrors() async throws {
        let queue = SerialExecutionQueue()

        #expect(try await queue.run { 42 } == 42)
        await #expect(throws: TestError(reason: "boom")) {
            try await queue.run { throw TestError(reason: "boom") }
        }
    }

    @Test func runThrowsAfterTheQueueIsFinished() async throws {
        let queue = SerialExecutionQueue()
        queue.finish()

        await #expect(throws: CancellationError.self) {
            try await queue.run { 1 }
        }
    }

    @Test func finishStillRunsQueuedOperations() async throws {
        let queue = SerialExecutionQueue()
        let ran = LockIsolated(false)

        queue.enqueue { ran.setValue(true) }
        queue.finish()

        try await waitUntil("queued operation") { ran.value }
    }
}

@Suite("AppLifecycleEvent")
struct AppLifecycleEventTests {
    @Test func mapsNotificationsToEvents() async throws {
        let center = NotificationCenter()
        let active = Notification.Name("test.active")
        let background = Notification.Name("test.background")
        let events = StreamRecorder(AppLifecycleEvent.events(from: center, names: [(active, .didBecomeActive), (background, .didEnterBackground)]))

        center.post(name: background, object: nil)
        center.post(name: active, object: nil)
        center.post(name: Notification.Name("unrelated"), object: nil)

        try await waitUntil("events") { events.values.count == 2 }
        #expect(events.values == [.didEnterBackground, .didBecomeActive])
    }
}

@Suite("RealtimeBackoff")
struct RealtimeBackoffTests {
    @Test(arguments: [(1, 0.5), (2, 1.0), (3, 2.0), (4, 4.0), (6, 16.0), (7, 30.0), (100, 30.0)])
    func delayGrowsExponentiallyWithJitterAndACap(attempt: Int, base: Double) {
        for _ in 0..<20 {
            let delay = RealtimeBackoff.delay(attempt: attempt)
            #expect(delay >= .milliseconds(Int(base * 1000)))
            #expect(delay <= .milliseconds(Int(base * 1250)))
        }
    }
}
