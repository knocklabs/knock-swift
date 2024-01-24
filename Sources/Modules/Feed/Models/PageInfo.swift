//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    struct PageInfo: Codable {
        public var before: String?
        public var after: String?
        public var page_size: Int = 0
    }
}
