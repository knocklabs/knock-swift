//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/18/24.
//

import Foundation

public extension Knock {
    
    struct Block: Codable {
        public let content: String
        public let name: String
        public let rendered: String
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.Block.CodingKeys> = try decoder.container(keyedBy: Knock.Block.CodingKeys.self)
            self.content = try container.decode(String.self, forKey: Knock.Block.CodingKeys.content)
            self.name = try container.decode(String.self, forKey: Knock.Block.CodingKeys.name)
            self.rendered = try container.decode(String.self, forKey: Knock.Block.CodingKeys.rendered)
        }
        
        public init(content: String, name: String, rendered: String) {
            self.content = content
            self.name = name
            self.rendered = rendered
        }
    }
    
}
