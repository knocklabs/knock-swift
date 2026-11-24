//
//  SocketGatewayConnectionCache.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation

/// Reuses a signed gateway URL until shortly before it expires.
///
/// Failed fetches store nothing, and concurrent fetches are not deduplicated.
internal actor SocketGatewayConnectionCache {
    /// A cached URL is refetched this long before it expires.
    static let expiryPadding: TimeInterval = 5

    private let fetch: @Sendable () async throws -> SocketGatewayConnection
    private let now: @Sendable () -> Date
    private var cached: SocketGatewayConnection?

    init(
        fetch: @escaping @Sendable () async throws -> SocketGatewayConnection,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetch = fetch
        self.now = now
    }

    func get() async throws -> SocketGatewayConnection {
        if let cached, cached.expiresAt.addingTimeInterval(-Self.expiryPadding) > now() {
            return cached
        }
        let connection = try await fetch()
        cached = connection
        return connection
    }

    func invalidate() {
        cached = nil
    }
}
