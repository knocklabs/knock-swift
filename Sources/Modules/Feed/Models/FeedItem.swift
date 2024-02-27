//
//  FeedItem.swift
//
//
//  Created by Matt Gardner on 2/27/24.
//

import Foundation

public extension Knock {

    struct FeedItem: Codable {
        public let __cursor: String
        public let actors: [User]?
        public let activities: [FeedItemActivity]?
        public let blocks: [Block]
        public let data: [String: AnyCodable]? // GenericData
        public let id: String
        public let inserted_at: Date?
        public let interacted_at: Date?
        public let clicked_at: Date?
        public let link_clicked_at: Date?
        public var read_at: Date?
        public var seen_at: Date?
        public let tenant: String?
        public let total_activities: Int
        public let total_actors: Int
        public let updated_at: Date?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.FeedItem.CodingKeys> = try decoder.container(keyedBy: Knock.FeedItem.CodingKeys.self)
            self.__cursor = try container.decode(String.self, forKey: Knock.FeedItem.CodingKeys.__cursor)
            self.actors = try container.decodeIfPresent([User].self, forKey: Knock.FeedItem.CodingKeys.actors)
            self.activities = try container.decodeIfPresent([FeedItemActivity].self, forKey: Knock.FeedItem.CodingKeys.activities)
            self.blocks = try container.decode([Knock.Block].self, forKey: Knock.FeedItem.CodingKeys.blocks)
            self.data = try container.decodeIfPresent([String : AnyCodable].self, forKey: Knock.FeedItem.CodingKeys.data)
            self.id = try container.decode(String.self, forKey: Knock.FeedItem.CodingKeys.id)
            self.inserted_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.inserted_at)
            self.interacted_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.interacted_at)
            self.clicked_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.clicked_at)
            self.link_clicked_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.link_clicked_at)
            self.read_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.read_at)
            self.seen_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.seen_at)
            self.tenant = try container.decodeIfPresent(String.self, forKey: Knock.FeedItem.CodingKeys.tenant)
            self.total_activities = try container.decode(Int.self, forKey: Knock.FeedItem.CodingKeys.total_activities)
            self.total_actors = try container.decode(Int.self, forKey: Knock.FeedItem.CodingKeys.total_actors)
            self.updated_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.updated_at)
        }
        
        public init(__cursor: String, actors: [User]?, activities: [FeedItemActivity]?, blocks: [Block], data: [String : AnyCodable]?, id: String, inserted_at: Date?, interacted_at: Date?, clicked_at: Date?, link_clicked_at: Date?, read_at: Date? = nil, seen_at: Date? = nil, tenant: String, total_activities: Int, total_actors: Int, updated_at: Date?) {
            self.__cursor = __cursor
            self.blocks = blocks
            self.actors = actors
            self.activities = activities
            self.data = data
            self.id = id
            self.inserted_at = inserted_at
            self.read_at = read_at
            self.seen_at = seen_at
            self.tenant = tenant
            self.total_activities = total_activities
            self.total_actors = total_actors
            self.updated_at = updated_at
            self.interacted_at = interacted_at
            self.clicked_at = clicked_at
            self.link_clicked_at = link_clicked_at
        }
    }
    
    struct FeedMetadata: Codable {
        public var total_count: Int = 0
        public var unread_count: Int = 0
        public var unseen_count: Int = 0
    }
}
