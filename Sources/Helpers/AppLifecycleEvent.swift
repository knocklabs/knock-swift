//
//  AppLifecycleEvent.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
#if canImport(Network)
import Network
#endif
#if canImport(UIKit)
import UIKit
#endif

internal enum AppLifecycleEvent: Sendable, Equatable {
    case didBecomeActive
    case didEnterBackground
    /// The device regained a usable network path after losing it.
    case networkBecameAvailable

    /// The app's foreground/background transitions and network recoveries.
    static func systemEvents(notificationCenter: NotificationCenter = .default) -> AsyncStream<AppLifecycleEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: AppLifecycleEvent.self)
        let applicationTask = Task {
            for await event in applicationEvents(notificationCenter: notificationCenter) {
                continuation.yield(event)
            }
        }
        let networkTask = Task {
            for await event in networkEvents() {
                continuation.yield(event)
            }
        }
        continuation.onTermination = { _ in
            applicationTask.cancel()
            networkTask.cancel()
        }
        return stream
    }

    private static func applicationEvents(notificationCenter: NotificationCenter) -> AsyncStream<AppLifecycleEvent> {
        #if canImport(UIKit)
        let (stream, continuation) = AsyncStream.makeStream(of: AppLifecycleEvent.self)
        let task = Task {
            let names = await MainActor.run {
                [
                    (UIApplication.didBecomeActiveNotification, AppLifecycleEvent.didBecomeActive),
                    (UIApplication.didEnterBackgroundNotification, AppLifecycleEvent.didEnterBackground),
                ]
            }
            for await event in events(from: notificationCenter, names: names) {
                continuation.yield(event)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
        #else
        return AsyncStream { $0.finish() }
        #endif
    }

    /// `networkBecameAvailable` whenever the network path becomes satisfied after being unsatisfied.
    private static func networkEvents() -> AsyncStream<AppLifecycleEvent> {
        #if canImport(Network)
        AsyncStream { continuation in
            let monitor = PathMonitor()
            let wasSatisfied = LockIsolated<Bool?>(nil)
            monitor.start { isSatisfied in
                let previous = wasSatisfied.withLock { value in
                    defer { value = isSatisfied }
                    return value
                }
                if isSatisfied, previous == false {
                    continuation.yield(.networkBecameAvailable)
                }
            }
            continuation.onTermination = { _ in monitor.cancel() }
        }
        #else
        AsyncStream { $0.finish() }
        #endif
    }

    /// Maps notifications posted to `notificationCenter` to lifecycle events. Observers are removed when the stream terminates.
    static func events(
        from notificationCenter: NotificationCenter,
        names: [(Notification.Name, AppLifecycleEvent)]
    ) -> AsyncStream<AppLifecycleEvent> {
        AsyncStream { continuation in
            let observers = NotificationObservers(
                center: notificationCenter,
                tokens: names.map { name, event in
                    notificationCenter.addObserver(forName: name, object: nil, queue: nil) { _ in
                        continuation.yield(event)
                    }
                }
            )
            continuation.onTermination = { _ in observers.remove() }
        }
    }
}

#if canImport(Network)
/// `NWPathMonitor` is thread-safe; it only delivers updates on the queue passed to `start`.
private final class PathMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.knock.feed.network-monitor")

    func start(_ onUpdate: @escaping @Sendable (_ isSatisfied: Bool) -> Void) {
        monitor.pathUpdateHandler = { path in onUpdate(path.status == .satisfied) }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}
#endif

/// Observer tokens are opaque, never mutated, and `NotificationCenter.removeObserver(_:)` is thread-safe.
private final class NotificationObservers: @unchecked Sendable {
    private let center: NotificationCenter
    private let tokens: [NSObjectProtocol]

    init(center: NotificationCenter, tokens: [NSObjectProtocol]) {
        self.center = center
        self.tokens = tokens
    }

    func remove() {
        tokens.forEach(center.removeObserver)
    }
}
