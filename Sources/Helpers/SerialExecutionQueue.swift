//
//  SerialExecutionQueue.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// Runs async operations one at a time, in the order they were enqueued.
///
/// Fire-and-forget APIs (such as `FeedManager.connectToFeed()`) enqueue their work here so that a
/// `connect` followed by a `disconnect` can never be reordered by the scheduler.
internal final class SerialExecutionQueue: Sendable {
    typealias Operation = @Sendable () async -> Void

    private let continuation: AsyncStream<Operation>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Operation.self, bufferingPolicy: .unbounded)
        self.continuation = continuation
        Task {
            for await operation in stream {
                await operation()
            }
        }
    }

    deinit {
        continuation.finish()
    }

    func enqueue(_ operation: @escaping Operation) {
        continuation.yield(operation)
    }

    /// Enqueues `operation` and suspends until it has run, returning its result.
    func run<Result: Sendable>(_ operation: @escaping @Sendable () async throws -> Result) async throws -> Result {
        try await withCheckedThrowingContinuation { (resultContinuation: CheckedContinuation<Result, Error>) in
            let result = continuation.yield {
                do {
                    resultContinuation.resume(returning: try await operation())
                } catch {
                    resultContinuation.resume(throwing: error)
                }
            }
            if case .terminated = result {
                resultContinuation.resume(throwing: CancellationError())
            }
        }
    }

    /// Stops accepting new work. Operations that were already enqueued still run.
    func finish() {
        continuation.finish()
    }
}
