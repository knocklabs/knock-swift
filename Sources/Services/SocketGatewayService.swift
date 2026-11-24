//
//  SocketGatewayService.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation

/// A signed websocket URL returned by the socket gateway.
internal struct SocketGatewayConnection: Sendable, Equatable {
    var signedUrl: String
    var expiresAt: Date
}

/// The gateway answered with a connection mode this SDK cannot use (anything other than `websocket`).
internal struct UnsupportedSocketModeError: Error, Equatable, LocalizedError {
    var mode: String?

    var errorDescription: String? {
        "Unsupported socket mode: \(mode ?? "none")"
    }
}

internal struct SocketConnectResponse: Codable, Sendable {
    var url: String?
    // Decoded as a string: the gateway sends `2026-11-16T19:02:21Z`, which the shared date strategy does not accept.
    var expires_at: String?
    var mode: String?
}

/// Asks the socket gateway where to connect.
internal final class SocketGatewayService: KnockAPIService {
    /// Makes no retries of its own; the socket's reconnect backoff is the retry.
    func fetchConnection() async throws -> SocketGatewayConnection {
        let response: SocketConnectResponse = try await post(path: "/sockets/connect", body: nil)
        return try Self.connection(from: response)
    }

    static func connection(from data: Data) throws -> SocketGatewayConnection {
        guard let response = try? JSONDecoder().decode(SocketConnectResponse.self, from: data) else {
            throw invalidResponse
        }
        return try connection(from: response)
    }

    static func connection(from response: SocketConnectResponse) throws -> SocketGatewayConnection {
        guard let url = response.url, !url.isEmpty, let expiresAt = parseDate(response.expires_at) else {
            throw invalidResponse
        }
        guard response.mode == "websocket" else {
            throw UnsupportedSocketModeError(mode: response.mode)
        }
        return SocketGatewayConnection(signedUrl: url, expiresAt: expiresAt)
    }

    private static var invalidResponse: Knock.KnockError {
        .runtimeError("Invalid socket connect response")
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: string) ?? fractional.date(from: string)
    }
}
