//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation

public extension Knock {
    // MARK: Preferences
    
    /**
     This struct is here to improve the ease of use in SwiftUI or UIKit. It's intented to be created from a `ChannelTypePreferences` struct using the method `asArray()` that returns an array of `ChannelTypePreferenceItem` that contains only the preferences that are not nil.
     
     It conforms to `Equatable` to be able to be monitored with `onChange` inside a SwiftUI List
     */
    struct ChannelTypePreferenceItem: Identifiable, Equatable {
        public static func == (lhs: Knock.ChannelTypePreferenceItem, rhs: Knock.ChannelTypePreferenceItem) -> Bool {
            switch lhs.value {
            case .left(let booll):
                switch rhs.value {
                case .left(let boolr):
                    return booll == boolr
                default:
                    return false
                }
            case .right(let leftCa):
                switch rhs.value {
                case .right(let rightCa):
                    return rightCa.conditions == leftCa.conditions
                default:
                    return false
                }
            }
        }
        
        public var id: ChannelTypeKey
        
        /**
         If this value is of type `ConditionsArray`, you must ensure that it has at least one element inside `conditions`, otherwise, an error will arise when saving the preferences.
         */
        public var value: Either<Bool, ConditionsArray>
        
        public init(id: ChannelTypeKey, value: Either<Bool, ConditionsArray>) {
            self.id = id
            self.value = value
        }
    }
    
    /**
     This struct will be converted to a dictionary when it's encoded to be sent to the API and it will only include the keys that are not set to nil
     When decoding from the API, if the key does not exists, the corresponding attribute will be nil here on the struct
     
     For convenient use in SwiftUI, you can convert this struct to  an array of `ChannelTypePreferenceItem` using the method `asArray()`.
     
     TODO: Just like the JS client, it would be great to pull this in (the keys/attributes) from an external location; it may be a bit tricky since Swift wants concrete types, but it may be a fun experiment to try to solve this.
     
     - Attention: for each attribute, if the value is of type `ConditionsArray`, you must ensure that it has at least one element inside `conditions`, otherwise, an error will arise when saving the preferences.
     */
    struct ChannelTypePreferences: Codable {
        public var email: Either<Bool, ConditionsArray>?
        public var in_app_feed: Either<Bool, ConditionsArray>?
        public var sms: Either<Bool, ConditionsArray>?
        public var push: Either<Bool, ConditionsArray>?
        public var chat: Either<Bool, ConditionsArray>?
        
        public func asArray() -> [ChannelTypePreferenceItem] {
            var array = [ChannelTypePreferenceItem]()
            
            if let bool = email {
                array.append(Knock.ChannelTypePreferenceItem(id: .email, value: bool))
            }
            
            if let bool = in_app_feed {
                array.append(Knock.ChannelTypePreferenceItem(id: .in_app_feed, value: bool))
            }
            
            if let bool = sms {
                array.append(Knock.ChannelTypePreferenceItem(id: .sms, value: bool))
            }
            
            if let bool = push {
                array.append(Knock.ChannelTypePreferenceItem(id: .push, value: bool))
            }
            
            if let bool = chat {
                array.append(Knock.ChannelTypePreferenceItem(id: .chat, value: bool))
            }
            
            return array
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.ChannelTypePreferences.CodingKeys> = try decoder.container(keyedBy: Knock.ChannelTypePreferences.CodingKeys.self)
            self.email = try container.decodeIfPresent(Either<Bool, ConditionsArray>.self, forKey: Knock.ChannelTypePreferences.CodingKeys.email)
            self.in_app_feed = try container.decodeIfPresent(Either<Bool, ConditionsArray>.self, forKey: Knock.ChannelTypePreferences.CodingKeys.in_app_feed)
            self.sms = try container.decodeIfPresent(Either<Bool, ConditionsArray>.self, forKey: Knock.ChannelTypePreferences.CodingKeys.sms)
            self.push = try container.decodeIfPresent(Either<Bool, ConditionsArray>.self, forKey: Knock.ChannelTypePreferences.CodingKeys.push)
            self.chat = try container.decodeIfPresent(Either<Bool, ConditionsArray>.self, forKey: Knock.ChannelTypePreferences.CodingKeys.chat)
        }
        
        public init () {}
    }
    
    enum ChannelTypeKey: String, CaseIterable, Codable {
        case email
        case in_app_feed
        case sms
        case push
        case chat
    }
    
    /**
     Struct to model a condition, see [here](https://docs.knock.app/send-and-manage-data/conditions#modeling-conditions) for more info
     */
    struct Condition: Codable, Equatable, Identifiable {
        public var id = UUID.init().uuidString
        
        public let variable: String
        public let operation: String // TODO: check this case. `operator` is a reserved word in Swift. That's why it's called `operation` in this Swift struct
        public let argument: String
        
        private enum CodingKeys: String, CodingKey {
                case variable
                case `operator` // See the backticks because it's a reserved word in Swift
                case argument
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.Condition.CodingKeys> = try decoder.container(keyedBy: Knock.Condition.CodingKeys.self)
            self.variable = try container.decode(String.self, forKey: Knock.Condition.CodingKeys.variable)
            self.operation = try container.decode(String.self, forKey: Knock.Condition.CodingKeys.operator)
            self.argument = try container.decode(String.self, forKey: Knock.Condition.CodingKeys.argument)
        }
        
        public init(variable: String, operation: String, argument: String) {
            self.variable = variable
            self.operation = operation
            self.argument = argument
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.variable, forKey: .variable)
            try container.encode(self.operation, forKey: .operator)
            try container.encode(self.argument, forKey: .argument)
        }
    }
    
    struct ConditionsArray: Codable {
        public var conditions: [Condition]
        
        public init(conditions: [Condition]) {
            self.conditions = conditions
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.ConditionsArray.CodingKeys> = try decoder.container(keyedBy: Knock.ConditionsArray.CodingKeys.self)
            self.conditions = try container.decodeIfPresent([Knock.Condition].self, forKey: Knock.ConditionsArray.CodingKeys.conditions) ?? []
        }
    }
    
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
    
    func getAllUserPreferences(completionHandler: @escaping ((Result<[PreferenceSet], Error>) -> Void)) {
        self.api.decodeFromGet([PreferenceSet].self, path: "/users/\(userId)/preferences", queryItems: nil, then: completionHandler)
    }
    
    func getUserPreferences(preferenceId: String, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        self.api.decodeFromGet(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", queryItems: nil, then: completionHandler)
    }
    
    func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        let payload = preferenceSet
        self.api.decodeFromPut(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", body: payload, then: completionHandler)
    }
}

public extension Encodable {
    /**
     This will allow types like `ChannelTypePreferences` to be transformed to a Dictionary to be encoded and sent to the API and only include non-nil attributes
     */
    func dictionary() -> [String:Any] {
        var dict = [String:Any]()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard let key = child.label else { continue }
            let childMirror = Mirror(reflecting: child.value)
            
            switch childMirror.displayStyle {
            case .struct, .class:
                let childDict = (child.value as! Encodable).dictionary()
                dict[key] = childDict
            case .collection:
                let childArray = (child.value as! [Encodable]).map({ $0.dictionary() })
                dict[key] = childArray
            case .set:
                let childArray = (child.value as! Set<AnyHashable>).map({ ($0 as! Encodable).dictionary() })
                dict[key] = childArray
            case .optional:
                if childMirror.children.count == 0 {
                    dict[key] = nil
                } else {
                    let (_, value) = childMirror.children.first!
                    
                    switch value {
                    case let value as Bool:
                        dict[key] = value
                    case let value as Int:
                        dict[key] = value
                    case let value as Int8:
                        dict[key] = value
                    case let value as Int16:
                        dict[key] = value
                    case let value as Int32:
                        dict[key] = value
                    case let value as Int64:
                        dict[key] = value
                    case let value as UInt:
                        dict[key] = value
                    case let value as UInt8:
                        dict[key] = value
                    case let value as UInt16:
                        dict[key] = value
                    case let value as UInt32:
                        dict[key] = value
                    case let value as UInt64:
                        dict[key] = value
                    case let value as Float:
                        dict[key] = value
                    case let value as Double:
                        dict[key] = value
                    case let value as String:
                        dict[key] = value
                    default:
                        dict[key] = nil
                    }
                }
            default:
                dict[key] = child.value
            }
        }
        
        return dict
    }
}

public extension [String: Either<Bool, Knock.WorkflowPreference>] {
    func toArrays() -> Knock.WorkflowPreferenceItems {
        var result = Knock.WorkflowPreferenceItems()
        
        self.sorted(by: { lhs, rhs in
            return lhs.key < rhs.key
        }).forEach { key, value in
            switch value {
            case .left(let value):
                let newItem = Knock.WorkflowPreferenceBoolItem(id: key, value: value)
                result.boolValues.append(newItem)
            case .right(let value):
                let channelPrefs = value.channel_types.asArray()
                let newItem = Knock.WorkflowPreferenceChannelTypesItem(id: key, channelTypes: channelPrefs, conditions: value.conditions)
                result.channelTypeValues.append(newItem)
            }
        }
        
        return result
    }
}

public extension Array<Knock.ChannelTypePreferenceItem> {
    func toChannelTypePreferences() -> Knock.ChannelTypePreferences {
        var result = Knock.ChannelTypePreferences()

        self.forEach{ item in
            switch item.id {
            case .email:
                result.email = item.value
            case .in_app_feed:
                result.in_app_feed = item.value
            case .sms:
                result.sms = item.value
            case .push:
                result.push = item.value
            case .chat:
                result.chat = item.value
            }
        }

        return result
    }
}
