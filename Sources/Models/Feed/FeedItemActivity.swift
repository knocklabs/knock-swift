//
//  FeedItemActivity.swift
//
//
//  Created by Matt Gardner on 2/27/24.
//

import Foundation

public extension Knock {

    struct FeedItemActivity: Codable {
        public let actor: User?
        public let recipient: User?
        public let data: [String: AnyCodable]? // GenericData
        public let id: String
        public let inserted_at: Date?
        public let updated_at: Date?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.FeedItemActivity.CodingKeys> = try decoder.container(keyedBy: Knock.FeedItemActivity.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: Knock.FeedItemActivity.CodingKeys.id)
            self.actor = try container.decodeIfPresent(User.self, forKey: Knock.FeedItemActivity.CodingKeys.actor)
            self.recipient = try container.decodeIfPresent(User.self, forKey: Knock.FeedItemActivity.CodingKeys.recipient)
            self.data = try container.decodeIfPresent([String : AnyCodable].self, forKey: Knock.FeedItemActivity.CodingKeys.data)
            self.inserted_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItemActivity.CodingKeys.inserted_at)
            self.updated_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItemActivity.CodingKeys.updated_at)
        }
    }
}
