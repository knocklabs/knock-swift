//
//  FeedConnectionState.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

public extension Knock {
    /// The lifecycle of a feed's realtime connection.
    enum FeedConnectionState: Sendable, Equatable {
        /// Not connected, and not trying to connect.
        case disconnected
        /// Opening the socket and joining the feed channel.
        case connecting
        /// The feed channel is joined and realtime events are being delivered.
        case connected
        /// The connection dropped and is being re-established. `attempt` starts at 1.
        case reconnecting(attempt: Int)
        /// The connection stopped because of an unrecoverable error. Call `connectToFeed()` to try again.
        case failed(RealtimeError)
    }

    enum RealtimeError: Error, Sendable, Equatable, LocalizedError {
        /// Knock rejected the request to join the feed channel.
        case channelJoinRejected(reason: String)
        /// The socket could not be connected.
        case connectionFailed(reason: String)
        /// Knock closed the feed channel.
        case channelClosed
        /// The feed was disconnected before the connection was established.
        case disconnected

        public var errorDescription: String? {
            switch self {
            case .channelJoinRejected(let reason):
                return "Knock rejected the feed channel join: \(reason)"
            case .connectionFailed(let reason):
                return "Unable to connect to the Knock feed socket: \(reason)"
            case .channelClosed:
                return "Knock closed the feed channel."
            case .disconnected:
                return "The feed was disconnected before the connection was established."
            }
        }
    }
}
