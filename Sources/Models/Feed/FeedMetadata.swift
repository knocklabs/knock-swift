//
//  FeedMetadata.swift
//  
//
//  Created by Matt Gardner on 4/12/24.
//

import Foundation

public extension Knock {
    struct FeedMetadata: Codable {
        public var total_count: Int = 0
        public var unread_count: Int = 0
        public var unseen_count: Int = 0
    }
}
