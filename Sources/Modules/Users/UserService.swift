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

internal struct MockUserService: KnockAPIService, UserServiceProtocol {
    
    internal func getUser(userId: String) async throws -> Knock.User {
        try await get(path: "/users/\(userId)", queryItems: nil)
    }
    
    internal func updateUser(user: Knock.User) async throws -> Knock.User {
        try await put(path: "/users/\(user.id)", body: user)
    }
}

//class MockAPIService2: KnockAPIService {
//    private var response: Knock.User?
//    private var error: Error?
//    
//    func setResponse<T>(response: T, error: Error?) {
//        
//    }
//
//    func get<T: Codable>(path: String, queryItems: [URLQueryItem]?) async throws -> T {
//        if let error = error {
//            throw error
//        }
//        if let response = getUserResponse as? T {
//            return response
//        }
//        throw NSError(domain: "", code: 0, userInfo: nil)  // Generic error
//    }
//
//    func put<T: Codable>(path: String, body: Encodable?) async throws -> T {
//        if let error = error {
//            throw error
//        }
//        if let response = updateUserResponse as? T {
//            return response
//        }
//        throw NSError(domain: "", code: 0, userInfo: nil)  // Generic error
//    }
//
//    // Implement other methods (post, delete) as needed
//}
