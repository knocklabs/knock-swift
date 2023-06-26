//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation

struct DynamicCodingKey: CodingKey {
    var intValue: Int? = nil
    var stringValue: String = ""
    
    init?(intValue: Int) {
        self.intValue = intValue
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
}

public extension Knock {
    // MARK: Users
    
    struct User: Codable {
        public let id: String
        public let name: String?
        public let email: String?
        public let avatar: String?
        public let phone_number: String?
        public let properties: [String: AnyCodable]?
        
        private enum CodingKeys: String, CodingKey, CaseIterable {
            case id
            case name
            case email
            case avatar
            case phone_number
        }
        
        public init(from decoder: Decoder) throws {
            let dynamicKeysContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            let allKeys = dynamicKeysContainer.allKeys
            let propertiesKeys = allKeys.filter { key in
                Self.CodingKeys.allCases.map { key in
                    key.stringValue
                }.contains(key.stringValue) == false && key.stringValue != "__typename"
            }
            
            let container: KeyedDecodingContainer<User.CodingKeys> = try decoder.container(keyedBy: User.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: User.CodingKeys.id)
            self.name = try container.decodeIfPresent(String.self, forKey: User.CodingKeys.name)
            self.email = try container.decodeIfPresent(String.self, forKey: User.CodingKeys.email)
            self.avatar = try container.decodeIfPresent(String.self, forKey: User.CodingKeys.avatar)
            self.phone_number = try container.decodeIfPresent(String.self, forKey: User.CodingKeys.phone_number)
            
            var properties: [String: AnyCodable]? = nil
            
            if !propertiesKeys.isEmpty {
                properties = [:]
                
                try propertiesKeys.forEach { key in
                    let value: AnyCodable = try dynamicKeysContainer.decode(AnyCodable.self, forKey: key)
                    properties!.updateValue(value, forKey: key.stringValue)
                }
            }
            
            self.properties = properties
        }
        
        public init(id: String, name: String?, email: String?, avatar: String?, phone_number: String?, properties: [String: AnyCodable]?) {
            self.id = id
            self.name = name
            self.email = email
            self.avatar = avatar
            self.phone_number = phone_number
            self.properties = properties
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            
            try container.encode(self.id, forKey: DynamicCodingKey.init(stringValue: "id")!)
            try container.encode(self.name, forKey: DynamicCodingKey.init(stringValue: "name")!)
            try container.encode(self.email, forKey: DynamicCodingKey.init(stringValue: "email")!)
            try container.encode(self.avatar, forKey: DynamicCodingKey.init(stringValue: "avatar")!)
            try container.encode(self.phone_number, forKey: DynamicCodingKey.init(stringValue: "phone_number")!)
            
            guard let properties = self.properties, !properties.isEmpty else {
                return
            }
            
            try properties.forEach { key, value in
                try container.encode(value, forKey: DynamicCodingKey.init(stringValue: key)!)
            }
        }
    }
    
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromPut(User.self, path: "/users/\(userId)", body: user, then: completionHandler)
    }
}
