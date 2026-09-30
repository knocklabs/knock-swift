//
//  FeedEvent.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

public extension Knock {
    /// A realtime event pushed by Knock over the feed's socket channel (for example `new-message`).
    struct FeedEvent: Sendable, Equatable {
        /// The event name, such as `new-message`.
        public let event: String
        /// The channel topic the event was received on (`feeds:<feed_id>:<user_id>`).
        public let topic: String
        /// The raw JSON payload of the event.
        public let payload: [String: AnyCodable]

        public init(event: String, topic: String, payload: [String: AnyCodable]) {
            self.event = event
            self.topic = topic
            self.payload = payload
        }

        /// Decodes the event payload into a strongly typed value.
        public func decodePayload<T: Decodable>(as type: T.Type = T.self) throws -> T {
            let data = try JSONEncoder().encode(payload)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    /// Returned from `FeedManager.on(eventName:completionHandler:)`. Call `cancel()` to stop receiving events.
    final class FeedEventSubscription: Sendable {
        private let task: Task<Void, Never>

        internal init(task: Task<Void, Never>) {
            self.task = task
        }

        public var isCancelled: Bool {
            task.isCancelled
        }

        public func cancel() {
            task.cancel()
        }
    }
}
