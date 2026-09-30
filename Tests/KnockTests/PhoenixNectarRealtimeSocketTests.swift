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
    @Test func channelFramesMapToSignals() {
        let reason = { "token expired" }
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.error), status: nil, reason: reason) == .errored)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.close), status: nil, reason: reason) == .closed)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.reply), status: .ok, reason: reason) == .rejoined)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.reply), status: .error, reason: reason) == .rejoinRejected(reason: "token expired"))
    }

    @Test func otherFramesAreNotSignals() {
        let reason: () -> String = {
            Issue.record("The reason is only read for rejected replies")
            return ""
        }
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.reply), status: .timeout, reason: reason) == nil)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.reply), status: nil, reason: reason) == nil)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .system(.heartbeat), status: nil, reason: reason) == nil)
        #expect(PhoenixNectarRealtimeSocket.signal(for: .named("new-message"), status: nil, reason: reason) == nil)
    }

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

    @Test func theSocketValidatesItsEndpoint() throws {
        #expect(throws: PhoenixError.malformedEndpoint("")) {
            try PhoenixNectarRealtimeSocket(configuration: RealtimeSocketConfiguration(endpoint: "", connectParams: [:]))
        }
        _ = try PhoenixNectarRealtimeSocket(
            configuration: RealtimeSocketConfiguration(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: ["api_key": "pk_test"])
        )
    }
}
