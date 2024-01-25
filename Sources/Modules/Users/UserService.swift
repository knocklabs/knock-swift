//
//  UserService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation
import OSLog

public extension Knock {
    
    private var logger: Logger {
        Logger(subsystem: Knock.loggingSubsytem, category: "UserService")
    }
    
    /**
     Sets the user for the current Knock instance. Will also register the device for push notifications if token and channelId are provided.
     You can also register the device for push notifications later on by calling Knock.registerTokenForAPNS()

     - Parameters:
        - userId: the user-id that will be used in the subsequent method calls
        - userToken: [optional] user token. Used in production when enhanced security is enabled
        - deviceToken: [optional] Options for customizing the Knock instance.
        - pushChannelId: [optional] Options for customizing the Knock instance.
     */
    func authenticate(userId: String, userToken: String? = nil, deviceToken: String? = nil, pushChannelId: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        self.userId = userId
        self.pushChannelId = pushChannelId
        self.userDeviceToken = deviceToken
        self.api.userToken = userToken
        if let token = deviceToken, let channelId = pushChannelId {
            self.registerTokenForAPNS(channelId: channelId, token: token) { result in
                switch result {
                case .success(_):
                    self.pushChannelId = pushChannelId
                    self.userDeviceToken = deviceToken
                    self.logger.debug("success registering the push token with Knock")
                    completion(.success(()))
                case .failure(let error):
                    self.logger.error("Error in registerTokenForAPNS: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func isAuthenticated(checkUserToken: Bool = false) -> Bool {
        if checkUserToken {
            return self.userId?.isEmpty == false && self.api.userToken?.isEmpty == false
        }
        return self.userId?.isEmpty == false
    }
    
    /**
     Sets the user for the current Knock instance. Will also register the device for push notifications if token and channelId are provided.
     You can also register the device for push notifications later on by calling Knock.registerTokenForAPNS()
     */
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let channelId = self.pushChannelId, let token = self.userDeviceToken  else {
            self.resetInstance()
            completion(.success(()))
            return
        }
        self.unregisterTokenForAPNS(channelId: channelId, token: token) { result in
            switch result {
            case .success(_):
                self.resetInstance()
                completion(.success(()))
            case .failure(let error):
                // Don't reset data if there was an error in the unregistration step. That way the client can retry the logout if they want.
                completion(.failure(error))
            }
        }
    }
    
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        performActionWithUserId( { userId, completion in
            self.api.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completion)
        }, completionHandler: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        performActionWithUserId( { userId, completion in
            self.api.decodeFromPut(User.self, path: "/users/\(userId)", body: user, then: completion)
        }, completionHandler: completionHandler)
    }
}
