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
        public let data: [String: AnyCodable]?
        
        public init(channel_id: String, data: [String: AnyCodable]?) {
            self.channel_id = channel_id
            self.data = data
        }
    }

    struct Device: Codable, Equatable {
        public let token: String
        public let locale: String?
        public let timezone: String?
        
        public init(token: String, locale: String?, timezone: String?) {
            self.token = token
            self.locale = locale
            self.timezone = timezone
        }
    }
}
