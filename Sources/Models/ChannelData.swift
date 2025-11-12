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
        public let data: ChannelDataData?
    }

    struct ChannelDataData: Codable {
        public let tokens: [String]?
        public let devices: [Device]?
    }

    struct Device: Codable {
        public let token: String
        public let locale: String?
        public let timezone: String?
    }
}
