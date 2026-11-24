//
//  PhoenixNectarRealtimeSocketTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import PhoenixNectar
import Testing
@testable import Knock

@Suite("PhoenixNectarRealtimeSocket")
struct PhoenixNectarRealtimeSocketTests {
    @Test func transportJoinErrorsAreRetried() {
        let errors: [PhoenixError] = [.timeout, .notConnected, .channelClosed("feeds:1"), .bufferOverflow("full"), .protocolViolation("bad frame")]
        for error in errors {
            #expect(PhoenixNectarRealtimeSocket.joinError(from: error) == .transient(reason: error.localizedDescription))
        }
    }

    @Test func localJoinErrorsAreUnrecoverable() {
        let errors: [PhoenixError] = [.encodingFailure("params"), .decodingFailure("reply"), .malformedEndpoint("ws://")]
        for error in errors {
            #expect(PhoenixNectarRealtimeSocket.joinError(from: error) == .unrecoverable(reason: error.localizedDescription))
        }
    }

    @Test func rejectionReasonsAreReadFromTheReply() {
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: ["reason": "unauthorized"]) == "unauthorized")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: nil) == "unknown")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: [:]) == "unknown")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: ["code": 42]).contains("42"))
    }

    @Test func joinParametersThatCannotBeEncodedAreUnrecoverable() async throws {
        struct Params: Encodable, Sendable { let value = Double.nan }
        let socket = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { [:] }, fetchGatewayConnection: { throw TestError(reason: "unused") })

        do {
            _ = try await socket.join(topic: "feeds:1", params: Params())
            Issue.record("Expected the join to fail")
        } catch let error as RealtimeJoinError {
            guard case .unrecoverable = error else {
                Issue.record("Expected an unrecoverable join error, got \(error)")
                return
            }
        }
    }

    @Test func anUnsupportedGatewayModeDisconnectsWithoutReconnecting() async throws {
        let fetchCount = LockIsolated(0)
        let socket = try PhoenixNectarRealtimeSocket(
            endpoint: "wss://api.knock.app/ws/v1/websocket",
            connectParams: { ["api_key": "pk_test"] },
            fetchGatewayConnection: {
                fetchCount.withLock { $0 += 1 }
                throw UnsupportedSocketModeError(mode: "polling")
            }
        )
        let states = StreamRecorder(await socket.connectionStates())

        try await socket.connect()
        try await states.waitFor(.unsupportedMode("polling"))

        // The first reconnect backoff is at most 625ms.
        try await expectStaysTrue("a single gateway fetch", for: .seconds(1)) { fetchCount.value == 1 }
        #expect(!states.values.contains { state in
            switch state {
            case .reconnecting, .failed: return true
            default: return false
            }
        })
    }

    @Test func theSocketValidatesItsEndpoint() throws {
        #expect(throws: PhoenixError.malformedEndpoint("")) {
            try PhoenixNectarRealtimeSocket(endpoint: "", connectParams: { [:] }, fetchGatewayConnection: { throw TestError(reason: "unused") })
        }
        _ = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { ["api_key": "pk_test"] }, fetchGatewayConnection: { throw TestError(reason: "unused") })
    }
}

@Suite("ChannelSignalHub")
struct ChannelSignalHubTests {
    typealias Frame = ChannelSignalClassifier.Frame

    static func collect(_ stream: AsyncStream<RealtimeChannelSignal>) async -> [RealtimeChannelSignal] {
        var signals: [RealtimeChannelSignal] = []
        for await signal in stream {
            signals.append(signal)
        }
        return signals
    }

    @Test func aCrashRightAfterTheJoinReplyReachesTheJoiningStream() async {
        let hub = ChannelSignalHub()
        let signals = hub.register(topic: "feeds:1")
        hub.joinSent(topic: "feeds:1", ref: "2")
        hub.handle(Frame(topic: "feeds:1", event: .system(.reply), ref: "2", joinRef: "1", status: .ok)) { "" }
        hub.handle(Frame(topic: "feeds:1", event: .system(.error), ref: nil, joinRef: "1", status: nil)) { "" }
        hub.finishAll()

        #expect(await Self.collect(signals) == [.rejoined, .errored])
    }

    @Test func registeringATopicAgainFinishesTheEarlierStream() async {
        let hub = ChannelSignalHub()
        let first = hub.register(topic: "feeds:1")
        let second = hub.register(topic: "feeds:1")
        hub.handle(Frame(topic: "feeds:1", event: .system(.close), ref: nil, joinRef: nil, status: nil)) { "" }
        hub.remove(topic: "feeds:1")

        #expect(await Self.collect(first).isEmpty)
        #expect(await Self.collect(second) == [.closed])
    }

    @Test func framesForUnregisteredTopicsAreDropped() async {
        let hub = ChannelSignalHub()
        let signals = hub.register(topic: "feeds:1")
        hub.handle(Frame(topic: "feeds:2", event: .system(.error), ref: nil, joinRef: nil, status: nil)) { "" }
        hub.finishAll()

        #expect(await Self.collect(signals).isEmpty)
    }
}
