//
//  AppLifecycleEvent.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

internal enum AppLifecycleEvent: Sendable, Equatable {
    case didBecomeActive
    case didEnterBackground

    /// The app's foreground/background transitions.
    static func systemEvents(notificationCenter: NotificationCenter = .default) -> AsyncStream<AppLifecycleEvent> {
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
