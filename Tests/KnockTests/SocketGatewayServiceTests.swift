//
//  SocketGatewayServiceTests.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("SocketGatewayService")
struct SocketGatewayServiceTests {
    func parse(_ json: String) throws -> SocketGatewayConnection {
        try SocketGatewayService.connection(from: Data(json.utf8))
    }

    @Test func parsesAValidResponse() throws {
        let connection = try parse(#"{"url": "wss://gateway.knock.app/ws?sig=abc", "expires_at": "2026-11-16T19:02:21Z", "mode": "websocket"}"#)
        #expect(connection.signedUrl == "wss://gateway.knock.app/ws?sig=abc")
        #expect(connection.expiresAt == Date(timeIntervalSince1970: 1_794_855_741))
    }

    @Test func parsesFractionalSeconds() throws {
        let connection = try parse(#"{"url": "wss://g/ws", "expires_at": "2026-11-16T19:02:21.500Z", "mode": "websocket"}"#)
        #expect(connection.expiresAt == Date(timeIntervalSince1970: 1_794_855_741.5))
    }

    @Test(arguments: [
        #"{"expires_at": "2026-11-16T19:02:21Z", "mode": "websocket"}"#,
        #"{"url": "", "expires_at": "2026-11-16T19:02:21Z", "mode": "websocket"}"#,
        #"{"url": 42, "expires_at": "2026-11-16T19:02:21Z", "mode": "websocket"}"#,
        #"{"url": "wss://g/ws", "mode": "websocket"}"#,
        #"{"url": "wss://g/ws", "expires_at": "tomorrow", "mode": "websocket"}"#,
        #"{"url": "wss://g/ws", "expires_at": 1794855741, "mode": "websocket"}"#,
        "not json",
    ])
    func rejectsAnInvalidResponse(json: String) {
        #expect(throws: Knock.KnockError.self) { try parse(json) }
    }

    @Test(arguments: [
        (#"{"url": "wss://g/ws", "expires_at": "2026-11-16T19:02:21Z"}"#, String?.none),
        (#"{"url": "wss://g/ws", "expires_at": "2026-11-16T19:02:21Z", "mode": "polling"}"#, "polling"),
    ])
    func rejectsAnUnsupportedMode(json: String, mode: String?) {
        #expect(throws: UnsupportedSocketModeError(mode: mode)) { try parse(json) }
    }

    @Test func invalidFieldsAreReportedBeforeTheMode() {
        #expect(throws: Knock.KnockError.self) { try parse(#"{"expires_at": "2026-11-16T19:02:21Z", "mode": "polling"}"#) }
    }
}
