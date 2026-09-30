//
//  LockIsolated.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// A value whose every read and write is serialized through a lock, so it can be shared across concurrency domains.
internal final class LockIsolated<Value: Sendable>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        withLock { $0 }
    }

    func setValue(_ newValue: Value) {
        // Returned out of the lock so the old value is released after unlocking, where a deinit it triggers can use
        // this lock.
        _ = withLock { value in
            defer { value = newValue }
            return value
        }
    }

    @discardableResult
    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }
}
