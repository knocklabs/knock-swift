//
//  FeedManager.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation
import SwiftPhoenixClient
import OSLog
import UIKit

public extension Knock {

    /// Main-actor isolated. The underlying Phoenix `Socket` and `Channel` are not
    /// thread-safe, and the SDK's own `UIApplication.didBecomeActiveNotification`
    /// observer (registered below with `queue: .main`) calls `connectToFeed()`
    /// from the main queue. Annotating the whole class as `@MainActor` forces
    /// every external caller to do the same, eliminating a whole class of
    /// data-race crashes (`objc_retain` during foregrounding).
    @MainActor
    class FeedManager {
        internal var feedModule: FeedModule!
        private var foregroundObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?

        public init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) async throws {
            self.feedModule = try await FeedModule(feedId: feedId, options: options)
            registerForAppLifecycleNotifications()
        }

        public init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) throws {
            Task {
                self.feedModule = try await FeedModule(feedId: feedId, options: options)
                registerForAppLifecycleNotifications()
            }
        }

        // `deinit` cannot be `@MainActor`-isolated, but `NotificationCenter.removeObserver`
        // is thread-safe, so we capture the observer tokens into locals and hand them to a
        // free function that can run from any isolation domain.
        deinit {
            let fg = foregroundObserver
            let bg = backgroundObserver
            if let fg { NotificationCenter.default.removeObserver(fg) }
            if let bg { NotificationCenter.default.removeObserver(bg) }
        }

        private func registerForAppLifecycleNotifications() {
            foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                // `queue: .main` gives us a main-thread callback, but from Swift's point of
                // view we're still in a non-isolated closure. Hop explicitly to main-actor
                // isolation before touching `self`.
                Task { @MainActor [weak self] in
                    self?.didEnterForeground()
                }
            }

            backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.didEnterBackground()
                }
            }
        }

        private func didEnterForeground() {
            Knock.shared.feedManager?.connectToFeed()
        }

        private func didEnterBackground() {
            Knock.shared.feedManager?.disconnectFromFeed()
        }
        
        /**
         Connect to the feed via socket. This will initialize the connection. You should also call the `on(eventName, completionHandler)` function to delegate what should be executed on certain received events and the `disconnectFromFeed()` function to terminate the connection.

         - Parameters:
            - options: [optional] Options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
         */
        public func connectToFeed(options: FeedClientOptions? = nil) {
            feedModule.connectToFeed(options: options)
        }
        
        public func disconnectFromFeed() {
            feedModule.disconnectFromFeed()
        }
        
        public func on(eventName: String, completionHandler: @escaping ((Message) -> Void)) {
            feedModule.on(eventName: eventName, completionHandler: completionHandler)
        }
        
        /**
         Retrieves a feed of items in reverse chronological order
         
         - Parameters:
            - options: [optional] Options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
         */
        public func getUserFeedContent(options: FeedClientOptions? = nil) async throws -> Feed {
            try await self.feedModule.getUserFeedContent(options: options)
        }
        
        public func getUserFeedContent(options: FeedClientOptions? = nil, completionHandler: @escaping ((Result<Feed, Error>) -> Void)) {
            Task {
                do {
                    let feed = try await getUserFeedContent(options: options)
                    completionHandler(.success(feed))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        }
        
        /**
         Updates feed messages in bulk
         
         - Attention: The base scope for the call should take into account all of the options currently set on the feed, as well as being scoped for the current user. We do this so that we **ONLY** make changes to the messages that are currently in view on this feed, and not all messages that exist.

         - Parameters:
            - type: The kind of update
            - options: All the options currently set on the feed to scope as much as possible the bulk update
         */
        public func makeBulkStatusUpdate(type: KnockMessageStatusUpdateType, options: FeedClientOptions) async throws -> BulkOperation {
            try await feedModule.makeBulkStatusUpdate(type: type, options: options)
        }
        
        public func makeBulkStatusUpdate(type: KnockMessageStatusUpdateType, options: FeedClientOptions, completionHandler: @escaping ((Result<BulkOperation, Error>) -> Void)) {
            Task {
                do {
                    let operation = try await makeBulkStatusUpdate(type: type, options: options)
                    completionHandler(.success(operation))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        }
    }
}
