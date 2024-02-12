//
//  File.swift
//  
//
//  Created by Matt Gardner on 2/6/24.
//

import Foundation


public extension Knock {
    
    //https://docs.knock.app/reference#preferences#preferences
    
    struct PreferenceSet: Codable {
        public var id: String? = nil // default or tenant.id; TODO: check this, because the API allows any value to be used here, not only default and an existing tenant.id
        public var channel_types: ChannelTypePreferences = ChannelTypePreferences()
        public var workflows: [String: Either<Bool, WorkflowPreference>] = [:]
        public var categories: [String: Either<Bool, WorkflowPreference>] = [:]
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.PreferenceSet.CodingKeys> = try decoder.container(keyedBy: Knock.PreferenceSet.CodingKeys.self)
            self.id = try container.decodeIfPresent(String.self, forKey: Knock.PreferenceSet.CodingKeys.id)
            self.channel_types = try container.decodeIfPresent(Knock.ChannelTypePreferences.self, forKey: Knock.PreferenceSet.CodingKeys.channel_types) ?? ChannelTypePreferences()
            self.workflows = try container.decodeIfPresent([String : Either<Bool, Knock.WorkflowPreference>].self, forKey: Knock.PreferenceSet.CodingKeys.workflows) ?? [:]
            self.categories = try container.decodeIfPresent([String : Either<Bool, Knock.WorkflowPreference>].self, forKey: Knock.PreferenceSet.CodingKeys.categories) ?? [:]
        }
        
        public init() {}
    }
}
