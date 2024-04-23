//
//  Feed.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    // https://docs.knock.app/reference#get-feed#feeds
    struct Feed {
        public var entries: [Knock.FeedItem] = []
        public var meta: FeedMetadata = FeedMetadata()
        public var pageInfo: PageInfo = PageInfo()
        
        public init(entries: [FeedItem] = [], meta: FeedMetadata = FeedMetadata(), pageInfo: PageInfo = PageInfo()) {
            self.entries = entries
            self.meta = meta
            self.pageInfo = pageInfo
        }
    }
}

extension Knock.Feed: Codable {
    enum CodingKeys: String, CodingKey {
        case entries
        case meta
        case pageInfo = "page_info"
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.entries = try container.decodeIfPresent([Knock.FeedItem].self, forKey: .entries) ?? []
        self.meta = try container.decodeIfPresent(Knock.FeedMetadata.self, forKey: .meta) ?? Knock.FeedMetadata()
        self.pageInfo = try container.decodeIfPresent(Knock.PageInfo.self, forKey: .pageInfo) ?? Knock.PageInfo()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
        try container.encode(meta, forKey: .meta)
        try container.encode(pageInfo, forKey: .pageInfo)
    }
}
