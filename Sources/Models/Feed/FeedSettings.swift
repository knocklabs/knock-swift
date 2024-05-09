//
//  FeedSettings.swift
//
//
//  Created by Matt Gardner on 5/8/24.
//

import Foundation

internal extension Knock {
    struct FeedSettings: Codable {
        public let features: FeedFeatures
        
        struct FeedFeatures: Codable {
            public let brandingRequired: Bool
            
            enum CodingKeys: String, CodingKey {
                case brandingRequired = "branding_required"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.brandingRequired = try container.decode(Bool.self, forKey: .brandingRequired)
            }
            
            public init(brandingRequired: Bool) {
                self.brandingRequired = brandingRequired
            }
        }
    }
}
