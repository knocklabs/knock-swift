//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    struct PageInfo {
        public var before: String?
        public var after: String?
        public var pageSize: Int = 0
        public var totalCount: Int = 0
        
        public init(before: String? = nil, after: String? = nil, pageSize: Int = 0, totalCount: Int = 0) {
            self.before = before
            self.after = after
            self.pageSize = pageSize
            self.totalCount = totalCount
        }
    }
}

extension Knock.PageInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case before
        case after
        case pageSize = "page_size"
        case totalCount = "total_count"
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.before = try container.decodeIfPresent(String.self, forKey: .before)
        self.after = try container.decodeIfPresent(String.self, forKey: .after)
        self.pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? 0
        self.totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(before, forKey: .before)
        try container.encodeIfPresent(after, forKey: .after)
        try container.encode(pageSize, forKey: .pageSize)
        try container.encode(totalCount, forKey: .totalCount)
    }
}
