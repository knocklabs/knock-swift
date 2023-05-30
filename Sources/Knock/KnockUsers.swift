//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation

public extension Knock {
    // MARK: Users
    
    struct User: Codable {
        public let id: String
        public let name: String?
        public let email: String?
        public let avatar: String?
        public let phone_number: String?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.User.CodingKeys> = try decoder.container(keyedBy: Knock.User.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: Knock.User.CodingKeys.id)
            self.name = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.name)
            self.email = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.email)
            self.avatar = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.avatar)
            self.phone_number = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.phone_number)
        }
        
        public init(id: String, name: String?, email: String?, avatar: String?, phone_number: String?) {
            self.id = id
            self.name = name
            self.email = email
            self.avatar = avatar
            self.phone_number = phone_number
        }
    }
    
    func getUser(userId: String, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromPut(User.self, path: "/users/\(userId)/\(user.id)", body: user, then: completionHandler)
    }
}
