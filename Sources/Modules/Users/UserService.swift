//
//  UserService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

public extension Knock {
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromPut(User.self, path: "/users/\(userId)", body: user, then: completionHandler)
    }
}
