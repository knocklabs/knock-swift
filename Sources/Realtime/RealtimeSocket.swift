//
//  RealtimeSocket.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// The transport-level state of a realtime socket.
internal enum RealtimeConnectionState: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case disconnected(code: Int, reason: String?)
    case failed(reason: String)
}

internal struct RealtimeSocketConfiguration: Sendable, Equatable {
    /// The websocket endpoint, without query parameters (e.g. `wss://api.knock.app/ws/v1/websocket`).
    var endpoint: String
    /// Query parameters sent with every connection attempt (`vsn` is added by the socket implementation).
    var connectParams: [String: String]
}

/// Notifications about a joined channel that happen outside of the join request itself.
internal enum RealtimeChannelSignal: Sendable, Equatable {
    /// The server-side channel process crashed (`phx_error`). The channel must be joined again.
    case errored
    /// The server closed the channel (`phx_close`).
    case closed
    /// An automatic rejoin (after a reconnect) succeeded.
    case rejoined
    /// An automatic rejoin (after a reconnect) was rejected by the server.
    case rejoinRejected(reason: String)
}

internal enum RealtimeJoinError: Error, Equatable, LocalizedError {
    /// The server replied to the join with an error. Retrying with the same parameters will not help.
    case rejected(reason: String)
    /// The join could not complete (timeout, dropped connection, ...). It is safe to retry.
    case transient(reason: String)

    var errorDescription: String? {
        switch self {
        case .rejected(let reason), .transient(let reason):
            return reason
        }
    }
}

/// A Phoenix-style socket that can join channels.
///
/// This abstraction keeps the PhoenixNectar dependency out of the feed logic so that the connection state
/// machine can be tested deterministically.
internal protocol RealtimeSocket: Sendable {
    func connect() async throws
    /// Closes the socket. The socket will not reconnect, and all streams it vended are finished.
    func disconnect() async
    func connectionStates() async -> AsyncStream<RealtimeConnectionState>
    /// Joins `topic`. Throws `RealtimeJoinError`.
    func join<Params: Encodable & Sendable>(topic: String, params: Params) async throws -> any RealtimeChannel
}

internal protocol RealtimeChannel: Sendable {
    var topic: String { get }
    /// Payloads pushed by the server for `event`. The stream finishes when the underlying connection drops.
    func messages(event: String) async -> AsyncThrowingStream<[String: AnyCodable], Error>
    /// Channel signals. The stream lives until the socket is disconnected.
    func signals() async -> AsyncStream<RealtimeChannelSignal>
}

internal typealias RealtimeSocketFactory = @Sendable (RealtimeSocketConfiguration) throws -> any RealtimeSocket

internal enum RealtimeBackoff {
    /// Exponential backoff starting at 0.5s and capped at 30s, with up to 25% jitter so that many clients
    /// reconnecting after an outage don't all hit the server at the same moment. `attempt` starts at 1.
    static func delay(attempt: Int) -> Duration {
        let exponent = Double(min(max(attempt - 1, 0), 16))
        let base = min(0.5 * pow(2, exponent), 30)
        let jitter = Double.random(in: 0...0.25) * base
        return .milliseconds(Int((base + jitter) * 1000))
    }
}
