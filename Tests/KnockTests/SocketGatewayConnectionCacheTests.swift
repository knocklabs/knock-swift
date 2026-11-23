//
//  SocketGatewayConnectionCacheTests.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("SocketGatewayConnectionCache")
struct SocketGatewayConnectionCacheTests {
    let now = LockIsolated(Date(timeIntervalSince1970: 1_000))
    let fetchCount = LockIsolated(0)
    let failing = LockIsolated(false)

    func makeCache(lifetime: TimeInterval = 60) -> SocketGatewayConnectionCache {
        SocketGatewayConnectionCache(
            fetch: { [now, fetchCount, failing] in
                let count = fetchCount.withLock { value -> Int in
                    value += 1
                    return value
                }
                if failing.value { throw TestError(reason: "offline") }
                return SocketGatewayConnection(signedUrl: "wss://g/ws?n=\(count)", expiresAt: now.value.addingTimeInterval(lifetime))
            },
            now: { [now] in now.value }
        )
    }

    @Test func reusesAConnectionBeforeItExpires() async throws {
        let cache = makeCache()
        let first = try await cache.get()
        now.withLock { $0 += 30 }
        let second = try await cache.get()
        #expect(first == second)
        #expect(fetchCount.value == 1)
    }

    @Test func refetchesInsideTheExpiryPadding() async throws {
        let cache = makeCache()
        _ = try await cache.get()
        now.withLock { $0 += 54 }
        #expect(try await cache.get().signedUrl == "wss://g/ws?n=1")
        now.withLock { $0 += 1 }
        #expect(try await cache.get().signedUrl == "wss://g/ws?n=2")
    }

    @Test func invalidateForcesAFetch() async throws {
        let cache = makeCache()
        _ = try await cache.get()
        await cache.invalidate()
        _ = try await cache.get()
        #expect(fetchCount.value == 2)
    }

    @Test func failedFetchesAreNotCached() async throws {
        let cache = makeCache()
        failing.setValue(true)
        await #expect(throws: TestError.self) { try await cache.get() }
        failing.setValue(false)
        #expect(try await cache.get().signedUrl == "wss://g/ws?n=2")
        #expect(fetchCount.value == 2)
    }
}
