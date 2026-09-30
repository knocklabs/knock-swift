//
//  AsyncTestSupport.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
@testable import Knock

struct TimeoutError: Error, CustomStringConvertible {
    let description: String
}

/// A generic failure for fakes and test closures to throw.
struct TestError: Error, Equatable, LocalizedError {
    let reason: String

    var errorDescription: String? { reason }
}

/// Polls `condition` until it returns true, failing after `timeout`.
func waitUntil(
    _ message: @autoclosure () -> String = "condition",
    timeout: Duration = .seconds(3),
    isolation: isolated (any Actor)? = #isolation,
    _ condition: () async throws -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if try await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    if try await condition() { return }
    throw TimeoutError(description: "Timed out waiting for \(message())")
}

/// Checks that `condition` holds for the whole of `duration`, for asserting that something does *not* happen.
func expectStaysTrue(
    _ message: @autoclosure () -> String,
    for duration: Duration = .milliseconds(30),
    isolation: isolated (any Actor)? = #isolation,
    _ condition: () async throws -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: duration)
    repeat {
        guard try await condition() else {
            throw TestError(reason: "Expected \(message()) to stay true")
        }
        try await Task.sleep(for: .milliseconds(5))
    } while clock.now < deadline
}

/// Runs `operation`, failing if it doesn't finish within `timeout`.
func withTimeout<T: Sendable>(
    _ timeout: Duration = .seconds(3),
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError(description: "Operation timed out after \(timeout)")
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

/// Collects the elements of a stream in the background so tests can assert on them.
final class StreamRecorder<Element: Sendable>: Sendable {
    private let storage = LockIsolated<[Element]>([])
    private let finished = LockIsolated(false)
    private let task: LockIsolated<Task<Void, Never>?> = LockIsolated(nil)

    init(_ stream: AsyncStream<Element>) {
        task.setValue(Task { [storage, finished] in
            for await element in stream {
                storage.withLock { $0.append(element) }
            }
            finished.setValue(true)
        })
    }

    var values: [Element] { storage.value }
    var isFinished: Bool { finished.value }

    func cancel() {
        task.value?.cancel()
    }

    deinit {
        task.value?.cancel()
    }
}

extension StreamRecorder where Element: Equatable {
    func waitFor(_ element: Element, timeout: Duration = .seconds(3)) async throws {
        try await waitUntil("\(element) (recorded: \(values))", timeout: timeout) { values.contains(element) }
    }
}

/// Suspends callers until `open()` is called.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waiterCount: Int { waiters.count }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
