//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/18/24.
//

import Foundation

public extension Knock {    
    struct ChannelData: Codable {
        public let channel_id: String
        public let data: [String: AnyCodable]? // GenericData
    }
}
