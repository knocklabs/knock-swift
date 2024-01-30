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
            let user = try await userService.getUser()
            KnockLogger.log(type: .debug, category: .user, message: "getUser", status: .success)
            return user
        } catch let error {
            KnockLogger.log(type: .error, category: .user, message: "getUser", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    func updateUser(user: Knock.User) async throws -> Knock.User {
        do {
            let user = try await userService.updateUser(user: user)
            KnockLogger.log(type: .debug, category: .user, message: "updateUser", status: .success)
            return user
        } catch let error {
            KnockLogger.log(type: .error, category: .user, message: "updateUser", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
}

public extension Knock {
    
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



internal class AuthenticationModule {
    let userService = UserService()
    let channelService = ChannelService()
    
    private let logger: Logger =  Logger(subsystem: Knock.loggingSubsytem, category: "Authentication")
    
    // AuthenticateUser
    // logoutUser
    
    
//    func authenticateUser(userId: String, userToken: String?) async throws {
//        // TODO: remove previous userID and token.
//        
//        KnockEnvironment.shared.userId = userId
//        KnockEnvironment.shared.userToken = userToken
//    }
    
//    func authenticate(userId: String, userToken: String? = nil) {
//        self.userId = userId
//        self.api.userToken = userToken
//        if let token = deviceToken, let channelId = pushChannelId {
//            self.registerTokenForAPNS(channelId: channelId, token: token) { result in
//                switch result {
//                case .success(_):
//                    self.pushChannelId = pushChannelId
//                    self.userDeviceToken = deviceToken
//                    self.logger.debug("success registering the push token with Knock")
//                    completion(.success(()))
//                case .failure(let error):
//                    self.logger.error("Error in registerTokenForAPNS: \(error.localizedDescription)")
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
}

public extension Knock {

    func isAuthenticated(checkUserToken: Bool = false) -> Bool {
        let isUser = KnockEnvironment.shared.userId?.isEmpty == false
        if checkUserToken {
            return isUser && KnockEnvironment.shared.userToken?.isEmpty == false
        }
        return isUser
    }
    
    /**
     Set the current credentials for the user and their access token.
      Will also registerAPNS device token if set previously.
     You should consider using this in areas where you update your local user's state
     */
    func signIn(userId: String, userToken: String?) async throws {
        KnockEnvironment.shared.setUserInfo(userId: userId, userToken: userToken)
        
        if let token = KnockEnvironment.shared.userDevicePushToken, let channelId = KnockEnvironment.shared.pushChannelId {
            let _ = try await registerTokenForAPNS(channelId: channelId, token: token)
            return
        }
        
        return
    }
    
    func signIn(userId: String, userToken: String?, completionHandler: @escaping ((Result<Void, Error>) -> Void)) {
        Task {
            do {
                try await signIn(userId: userId, userToken: userToken)
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    /**
     Clears the current user id and access token
     You should call this when your user signs out
     It will remove the current tokens used for this user in Courier so they do not receive pushes they should not get
     */
    func signOut() async throws {
        guard let channelId = KnockEnvironment.shared.pushChannelId, let token = KnockEnvironment.shared.userDevicePushToken else {
            self.resetInstance()
            return
        }
        let _ = try await self.unregisterTokenForAPNS(channelId: channelId, token: token)
        self.resetInstance()
        return
    }
    
    func signOut(completionHandler: @escaping ((Result<Void, Error>) -> Void)) {
        Task {
            do {
                try await signOut()
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
}
