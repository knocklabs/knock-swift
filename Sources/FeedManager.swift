//
//  FeedManager.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {

    /// Fetches a user's feed and keeps a realtime connection to it.
    ///
    /// Realtime operations are processed one at a time, in the order they are called, so a `connectToFeed()` followed
    /// by a `disconnectFromFeed()` always ends disconnected. While connected, the connection is suspended when the app
    /// enters the background and re-established when it becomes active again.
    final class FeedManager: Sendable {
        internal let feedModule: FeedModule
        private let realtime: FeedRealtimeSession
        private let operations: SerialExecutionQueue
        private let lifecycleTask: Task<Void, Never>

        /// The id of the in-app feed channel.
        public var feedId: String {
            feedModule.feedId
        }

        /**
         Creates a feed manager, after checking that Knock is set up and a user is signed in.

         - Parameters:
            - feedId: The id of the in-app feed channel.
            - options: Default options for fetching the feed and filtering realtime events. Options passed to other methods are merged into these.
         */
        public convenience init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) async throws {
            let environment = Knock.shared.environment
            do {
                _ = try await environment.getSafeUserId()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "FeedManager", status: .fail, errorMessage: "Must sign user in before initializing the FeedManager")
                throw error
            }
            _ = try await environment.getSafePublishableKey()
            self.init(feedModule: FeedModule(feedId: feedId, options: options), lifecycleEvents: AppLifecycleEvent.systemEvents())
            Knock.shared.log(type: .debug, category: .feed, message: "FeedManager", status: .success)
        }

        /**
         Creates a feed manager. Knock must be set up and a user signed in before connecting or fetching the feed.

         - Parameters:
            - feedId: The id of the in-app feed channel.
            - options: Default options for fetching the feed and filtering realtime events. Options passed to other methods are merged into these.
         */
        public convenience init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) throws {
            self.init(feedModule: FeedModule(feedId: feedId, options: options), lifecycleEvents: AppLifecycleEvent.systemEvents())
        }

        internal init(feedModule: FeedModule, lifecycleEvents: AsyncStream<AppLifecycleEvent>) {
            let operations = SerialExecutionQueue()
            let realtime = feedModule.realtime
            self.feedModule = feedModule
            self.realtime = realtime
            self.operations = operations
            self.lifecycleTask = Task {
                for await event in lifecycleEvents {
                    switch event {
                    case .didEnterBackground:
                        operations.enqueue { await realtime.suspend() }
                    case .didBecomeActive:
                        operations.enqueue {
                            do {
                                try await realtime.resume()
                            } catch {
                                Knock.shared.log(type: .error, category: .feed, message: "Resuming feed connection", status: .fail, errorMessage: error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }

        deinit {
            lifecycleTask.cancel()
            let realtime = self.realtime
            operations.enqueue { await realtime.shutdown() }
            operations.finish()
        }

        // MARK: Realtime

        /**
         Connect to the feed via socket. This returns immediately; the connection is established in the background.
         Use `connect(options:)` to wait for the connection, and `events(named:)` or `on(eventName:completionHandler:)` to receive events.

         Calling this again with the same options while connected does nothing. Different options replace the connection.

         - Parameters:
            - options: [optional] Options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
         */
        public func connectToFeed(options: FeedClientOptions? = nil) {
            let realtime = self.realtime
            operations.enqueue {
                do {
                    try await realtime.connect(options: options)
                } catch {
                    Knock.shared.log(type: .error, category: .feed, message: "connectToFeed", status: .fail, errorMessage: error.localizedDescription)
                }
            }
        }

        /**
         Connect to the feed via socket and wait until the feed channel is joined.

         - Throws: `RealtimeError` if the connection fails or is disconnected before it's established, or an error if Knock isn't set up or no user is signed in.
         */
        public func connect(options: FeedClientOptions? = nil) async throws {
            let realtime = self.realtime
            try await operations.run { try await realtime.connect(options: options) }
            try await realtime.waitUntilConnected()
        }

        /// Disconnects from the feed. Event subscriptions stay registered and receive events again after the next connect.
        public func disconnectFromFeed() {
            Knock.shared.log(type: .debug, category: .feed, message: "Disconnecting from feed")
            let realtime = self.realtime
            operations.enqueue { await realtime.disconnect() }
        }

        /// Disconnects from the feed and waits for the socket to close.
        public func disconnect() async {
            let realtime = self.realtime
            _ = try? await operations.run { await realtime.disconnect() }
        }

        /**
         Returns a stream of realtime events with the given name, such as `new-message`.

         The subscription works across connections: it can be created before connecting, and keeps receiving events
         after a reconnect. Stop receiving events by cancelling the task iterating the stream.
         */
        public func events(named eventName: String) async -> AsyncStream<FeedEvent> {
            await realtime.events(named: eventName)
        }

        /**
         Calls `completionHandler` on the main actor for every realtime event with the given name, such as `new-message`.

         The subscription works across connections: it can be created before connecting, and keeps receiving events
         after a reconnect.

         - Returns: A subscription. Call `cancel()` on it to stop receiving events.
         */
        @discardableResult
        public func on(eventName: String, completionHandler: @escaping @MainActor (FeedEvent) -> Void) -> FeedEventSubscription {
            let realtime = self.realtime
            let task = Task {
                let events = await realtime.events(named: eventName)
                for await event in events {
                    await completionHandler(event)
                }
            }
            return FeedEventSubscription(task: task)
        }

        /// The current state of the realtime connection.
        public var connectionState: FeedConnectionState {
            get async { await realtime.state }
        }

        /// A stream of realtime connection states, starting with the current state.
        public func connectionStates() async -> AsyncStream<FeedConnectionState> {
            await realtime.connectionStates()
        }

        // MARK: Feed

        /**
         Retrieves a feed of items in reverse chronological order
         
         - Parameters:
            - options: [optional] Options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
         */
        public func getUserFeedContent(options: FeedClientOptions? = nil) async throws -> Feed {
            try await self.feedModule.getUserFeedContent(options: options)
        }
        
        public func getUserFeedContent(options: FeedClientOptions? = nil, completionHandler: @escaping @Sendable (Result<Feed, Error>) -> Void) {
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
        
        public func makeBulkStatusUpdate(type: KnockMessageStatusUpdateType, options: FeedClientOptions, completionHandler: @escaping @Sendable (Result<BulkOperation, Error>) -> Void) {
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
