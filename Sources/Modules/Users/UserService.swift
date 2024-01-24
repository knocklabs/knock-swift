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
    
    func authenticate(userId: String, userToken: String? = nil, deviceToken: String? = nil, pushChannelId: String? = nil) {
        self.userId = userId
        self.userToken = userToken
        if let token = deviceToken, let channelId = pushChannelId {
            self.registerTokenForAPNS(channelId: channelId, token: token) { result in
                switch result {
                case .success(_):
                    self.logger.debug("success registering the push token with Knock")
                case .failure(let error):
                    self.logger.error("error in registerTokenForAPNS: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func isAuthenticated(checkUserToken: Bool = false) -> Bool {
        if checkUserToken {
            return self.userId?.isEmpty == false && self.userToken?.isEmpty == false
        }
        return self.userId?.isEmpty == false
    }
    
    func logout() {
        self.userId = nil
        self.userToken = nil
    }
    
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api?.decodeFromGet(User.self, path: "/users/\(self.safeUserId)", queryItems: nil, then: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api?.decodeFromPut(User.self, path: "/users/\(self.safeUserId)", body: user, then: completionHandler)
    }
}
