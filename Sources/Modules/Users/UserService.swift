//
//  UserService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

internal protocol UserServiceProtocol {
    func getUser(userId: String) async throws -> Knock.User
    func updateUser(user: Knock.User) async throws -> Knock.User
}

internal struct UserService: KnockAPIService, UserServiceProtocol {
    
    internal func getUser(userId: String) async throws -> Knock.User {
        try await get(path: "/users/\(userId)", queryItems: nil)
    }
    
    internal func updateUser(user: Knock.User) async throws -> Knock.User {
        try await put(path: "/users/\(user.id)", body: user)
    }
}
