//
//  FeedItem.swift
//
//
//  Created by Matt Gardner on 2/27/24.
//

import Foundation

public extension Knock {

    struct FeedItem {
        public var __cursor: String
        public var actors: [User]?
        public var activities: [FeedItemActivity]?
        public var blocks: [ContentBlockBase]
        public var data: [String: AnyCodable]? // GenericData
        public var id: String
        public var inserted_at: Date?
        public var interacted_at: Date?
        public var clicked_at: Date?
        public var link_clicked_at: Date?
        public var read_at: Date?
        public var seen_at: Date?
        public var tenant: String?
        public var source: NotificationSource?
        public var total_activities: Int
        public var total_actors: Int
        public var updated_at: Date?
        
        public init(__cursor: String, actors: [User]?, activities: [FeedItemActivity]?, blocks: [ContentBlockBase], data: [String : AnyCodable]?, id: String, inserted_at: Date?, interacted_at: Date?, clicked_at: Date?, link_clicked_at: Date?, read_at: Date? = nil, seen_at: Date? = nil, tenant: String? = nil, source: NotificationSource? = nil, total_activities: Int, total_actors: Int, updated_at: Date?) {
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
            self.source = source
        }
    }
}

extension Knock.FeedItem: Codable {
    enum CodingKeys: String, CodingKey {
        case __cursor = "__cursor"
        case actors = "actors"
        case activities = "activities"
        case blocks = "blocks"
        case data = "data"
        case id = "id"
        case inserted_at = "inserted_at"
        case interacted_at = "interacted_at"
        case clicked_at = "clicked_at"
        case link_clicked_at = "link_clicked_at"
        case read_at = "read_at"
        case seen_at = "seen_at"
        case tenant = "tenant"
        case source = "source"
        case total_activities = "total_activities"
        case total_actors = "total_actors"
        case updated_at = "updated_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.__cursor = try container.decode(String.self, forKey: .__cursor)
        self.actors = try container.decodeIfPresent([Knock.User].self, forKey: .actors)
        self.activities = try container.decodeIfPresent([Knock.FeedItemActivity].self, forKey: .activities)
        self.data = try container.decodeIfPresent([String : AnyCodable].self, forKey: .data)
        self.id = try container.decode(String.self, forKey: .id)
        self.inserted_at = try container.decodeIfPresent(Date.self, forKey: .inserted_at)
        self.interacted_at = try container.decodeIfPresent(Date.self, forKey: .interacted_at)
        self.clicked_at = try container.decodeIfPresent(Date.self, forKey: .clicked_at)
        self.link_clicked_at = try container.decodeIfPresent(Date.self, forKey: .link_clicked_at)
        self.read_at = try container.decodeIfPresent(Date.self, forKey: .read_at)
        self.seen_at = try container.decodeIfPresent(Date.self, forKey: .seen_at)
        self.tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        self.source = try container.decodeIfPresent(Knock.NotificationSource.self, forKey: .source)
        self.total_activities = try container.decode(Int.self, forKey: .total_activities)
        self.total_actors = try container.decode(Int.self, forKey: .total_actors)
        self.updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
        
        var blocksContainer = try container.nestedUnkeyedContainer(forKey: .blocks)
        var blocksArray = [ContentBlockBase]()
        
        while !blocksContainer.isAtEnd {
            let blockDecoder = try blocksContainer.superDecoder()
            let blockContainer = try blockDecoder.container(keyedBy: DynamicCodingKey.self)
            let type = try blockContainer.decode(ContentBlockType.self, forKey: DynamicCodingKey(stringValue: "type")!)
            switch type {
            case .markdown:
                let markdownBlock = try Knock.MarkdownContentBlock(from: blockDecoder)
                blocksArray.append(markdownBlock)
            case .text:
                let textBlock = try Knock.TextContentBlock(from: blockDecoder)
                blocksArray.append(textBlock)
            case .buttonSet:
                let buttonSetBlock = try Knock.ButtonSetContentBlock(from: blockDecoder)
                blocksArray.append(buttonSetBlock)
            }
        }

        self.blocks = blocksArray
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
                
        try container.encode(__cursor, forKey: .__cursor)
        try container.encodeIfPresent(actors, forKey: .actors)
        try container.encodeIfPresent(activities, forKey: .activities)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(inserted_at, forKey: .inserted_at)
        try container.encodeIfPresent(interacted_at, forKey: .interacted_at)
        try container.encodeIfPresent(clicked_at, forKey: .clicked_at)
        try container.encodeIfPresent(link_clicked_at, forKey: .link_clicked_at)
        try container.encodeIfPresent(read_at, forKey: .read_at)
        try container.encodeIfPresent(seen_at, forKey: .seen_at)
        try container.encodeIfPresent(tenant, forKey: .tenant)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(total_activities, forKey: .total_activities)
        try container.encode(total_actors, forKey: .total_actors)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)

        var blocksContainer = container.nestedUnkeyedContainer(forKey: .blocks)
        for block in blocks {
            switch block.type {
            case .markdown:
                try blocksContainer.encode(block as! Knock.MarkdownContentBlock)
            case .text:
                try blocksContainer.encode(block as! Knock.TextContentBlock)
            case .buttonSet:
                try blocksContainer.encode(block as! Knock.ButtonSetContentBlock)
            }
        }
    }
}
