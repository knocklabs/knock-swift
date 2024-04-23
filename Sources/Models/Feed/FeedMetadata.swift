//
//  FeedMetadata.swift
//  
//
//  Created by Matt Gardner on 4/12/24.
//

import Foundation

public extension Knock {
    struct FeedMetadata {
        public var totalCount: Int = 0
        public var unreadCount: Int = 0
        public var unseenCount: Int = 0
        
        public init(totalCount: Int = 0, unreadCount: Int = 0, unseenCount: Int = 0) {
            self.totalCount = totalCount
            self.unreadCount = unreadCount
            self.unseenCount = unseenCount
        }
    }
}

extension Knock.FeedMetadata: Codable {
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case unreadCount = "unread_count"
        case unseenCount = "unseen_count"
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        self.unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        self.unseenCount = try container.decodeIfPresent(Int.self, forKey: .unseenCount) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalCount, forKey: .totalCount)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(unseenCount, forKey: .unseenCount)
    }
}

