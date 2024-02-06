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

    class FeedManager {
        private let feedModule: FeedModule
        private var foregroundObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?
        
        public init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) throws {
            self.feedModule = try FeedModule(feedId: feedId, options: options)
            registerForAppLifecycleNotifications()
        }
        
        deinit {
            unregisterFromAppLifecycleNotifications()
        }
        
        private func registerForAppLifecycleNotifications() {
            foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.didEnterForeground()
            }

            backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.didEnterBackground()
            }
        }

        private func unregisterFromAppLifecycleNotifications() {
            if let observer = foregroundObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = backgroundObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        /**
         Connect to the feed via socket. This will initialize the connection. You should also call the `on(eventName, completionHandler)` function to delegate what should be executed on certain received events and the `disconnectFromFeed()` function to terminate the connection.

         - Parameters:
            - options: options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
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
         Gets the content of the user feed

         - Parameters:
            - options: options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
            - completionHandler: the code to execute when the response is received
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
            - type: the kind of update
            - options: all the options currently set on the feed to scope as much as possible the bulk update
            - completionHandler: the code to execute when the response is received
         */
        public func makeBulkStatusUpdate(type: BulkChannelMessageStatusUpdateType, options: FeedClientOptions) async throws -> BulkOperation {
            try await feedModule.makeBulkStatusUpdate(type: type, options: options)
        }
        
        public func makeBulkStatusUpdate(type: BulkChannelMessageStatusUpdateType, options: FeedClientOptions, completionHandler: @escaping ((Result<BulkOperation, Error>) -> Void)) {
            Task {
                do {
                    let operation = try await makeBulkStatusUpdate(type: type, options: options)
                    completionHandler(.success(operation))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        }
        
        public func didEnterForeground() {
            Knock.shared.feedManager?.connectToFeed()
        }

        public func didEnterBackground() {
            Knock.shared.feedManager?.disconnectFromFeed()
        }
    }
}
