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
        let socket = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { [:] })

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

    @Test func theSocketValidatesItsEndpoint() throws {
        #expect(throws: PhoenixError.malformedEndpoint("")) {
            try PhoenixNectarRealtimeSocket(endpoint: "", connectParams: { [:] })
        }
        _ = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { ["api_key": "pk_test"] })
    }
}
