//
//  Extensions.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

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
