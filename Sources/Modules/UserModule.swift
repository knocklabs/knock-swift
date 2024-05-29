//
//  File.swift
//  
//
//  Created by Matt Gardner on 1/26/24.
//

import Foundation
import OSLog

internal class UserModule {
    let userService = UserService()
    
    func getUser() async throws -> Knock.User {
        do {
            let user = try await userService.getUser(userId: Knock.shared.environment.getSafeUserId())
            Knock.shared.log(type: .debug, category: .user, message: "getUser", status: .success)
            return user
        } catch let error {
            Knock.shared.log(type: .error, category: .user, message: "getUser", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    func updateUser(user: Knock.User) async throws -> Knock.User {
        do {
            let user = try await userService.updateUser(user: user)
            Knock.shared.log(type: .debug, category: .user, message: "updateUser", status: .success)
            return user
        } catch let error {
            Knock.shared.log(type: .error, category: .user, message: "updateUser", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
}

public extension Knock {
    
    /**
     Retrieve the current user, including all properties previously set.
     https://docs.knock.app/reference#get-user
     */
    func getUser() async throws -> User {
        return try await userModule.getUser()
    }
    
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        Task {
            do {
                let user = try await getUser()
                completionHandler(.success(user))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    /**
     Updates the current user and returns the updated User result.
     */
    func updateUser(user: User) async throws -> User {
        return try await userModule.updateUser(user: user)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        Task {
            do {
                let user = try await updateUser(user: user)
                completionHandler(.success(user))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
}

