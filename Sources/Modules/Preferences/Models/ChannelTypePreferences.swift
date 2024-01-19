//
//  ChannelTypePreferences.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    
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
    
    
    
    enum ChannelTypeKey: String, CaseIterable, Codable {
        case email
        case in_app_feed
        case sms
        case push
        case chat
    }
}
