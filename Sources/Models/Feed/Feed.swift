//
//  Feed.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    // https://docs.knock.app/reference#get-feed#feeds
    struct Feed: Codable {
        public var entries: [Knock.FeedItem] = []
        public var meta: FeedMetadata = FeedMetadata()
        public var page_info: PageInfo = PageInfo()
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.Feed.CodingKeys> = try decoder.container(keyedBy: Knock.Feed.CodingKeys.self)
            self.entries = try container.decode([Knock.FeedItem].self, forKey: Knock.Feed.CodingKeys.entries)
            self.meta = try container.decode(Knock.FeedMetadata.self, forKey: Knock.Feed.CodingKeys.meta)
            self.page_info = try container.decode(Knock.PageInfo.self, forKey: Knock.Feed.CodingKeys.page_info)
        }
        
        public init(entries: [FeedItem], meta: FeedMetadata, page_info: PageInfo) {
            self.entries = entries
            self.meta = meta
            self.page_info = page_info
        }
        
        public init() {}
    }
}
