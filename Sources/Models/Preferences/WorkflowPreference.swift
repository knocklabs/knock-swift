//
//  WorkflowPreference.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
    struct WorkflowPreference: Codable {
        public var channel_types: ChannelTypePreferences = ChannelTypePreferences()
        public var conditions: [Condition] = []
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.WorkflowPreference.CodingKeys> = try decoder.container(keyedBy: Knock.WorkflowPreference.CodingKeys.self)
            self.channel_types = try container.decodeIfPresent(ChannelTypePreferences.self, forKey: Knock.WorkflowPreference.CodingKeys.channel_types) ?? ChannelTypePreferences()
            self.conditions = try container.decodeIfPresent([Condition].self, forKey: Knock.WorkflowPreference.CodingKeys.conditions) ?? []
        }

        public init(channel_types: ChannelTypePreferences, conditions: [Condition]) {
            self.channel_types = channel_types
            self.conditions = conditions
        }
    }

    
    
    struct WorkflowPreferenceBoolItem: Identifiable, Equatable {
        public var id: String
        public var value: Bool
        
        public init(id: String, value: Bool) {
            self.id = id
            self.value = value
        }
    }
    
    struct WorkflowPreferenceChannelTypesItem: Identifiable, Equatable {
        public var id: String // workflow or category id
        public var channelTypes: [ChannelTypePreferenceItem] = []
        public var conditions: [Condition] = []
        
        public init(id: String, channelTypes: [ChannelTypePreferenceItem], conditions: [Condition]) {
            self.id = id
            self.channelTypes = channelTypes
            self.conditions = conditions
        }
    }
    
    struct WorkflowPreferenceItems: Identifiable {
        public var id = UUID.init().uuidString
        
        public var boolValues: [WorkflowPreferenceBoolItem] = []
        public var channelTypeValues: [WorkflowPreferenceChannelTypesItem] = []
        
        public func toPreferenceDictionary() -> [String: Either<Bool, Knock.WorkflowPreference>] {
            var result = [String: Either<Bool, Knock.WorkflowPreference>]()
            
            boolValues.forEach { boolItem in
                result[boolItem.id] = .left(boolItem.value)
            }
            
            channelTypeValues.forEach { channelsItem in
                let workflowPreference = WorkflowPreference(channel_types: channelsItem.channelTypes.toChannelTypePreferences(), conditions: channelsItem.conditions)
                result[channelsItem.id] = .right(workflowPreference)
            }
            
            return result
        }
        
        public init(boolValues: [WorkflowPreferenceBoolItem], channelTypeValues: [WorkflowPreferenceChannelTypesItem]) {
            self.boolValues = boolValues
            self.channelTypeValues = channelTypeValues
        }
        
        public init() {}
    }
}
