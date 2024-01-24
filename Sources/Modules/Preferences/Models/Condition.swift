//
//  Condition.swift
//  
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation
public extension Knock {
    
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
}
