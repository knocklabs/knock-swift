//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    struct NotificationSource: Codable {
        public let key: String
        public let version_id: String
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.NotificationSource.CodingKeys> = try decoder.container(keyedBy: Knock.NotificationSource.CodingKeys.self)
            self.key = try container.decode(String.self, forKey: Knock.NotificationSource.CodingKeys.key)
            self.version_id = try container.decode(String.self, forKey: Knock.NotificationSource.CodingKeys.version_id)
        }
        
        public init(key: String, version_id: String) {
            self.key = key
            self.version_id = version_id
        }
    }
    
}
