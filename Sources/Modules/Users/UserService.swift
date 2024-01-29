//
//  UserService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

internal class UserService: KnockAPIService {
    
    internal func getUser() async throws -> Knock.User {
        try await get(path: "/users/\(KnockEnvironment.shared.getSafeUserId())", queryItems: nil)
    }
    
    internal func updateUser(user: Knock.User) async throws -> Knock.User {
        try await put(path: "/users/\(KnockEnvironment.shared.getSafeUserId())", body: user)
    }
}
