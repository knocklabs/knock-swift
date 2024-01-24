//
//  UserService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

public extension Knock {
    
    func authenticate(userId: String, userToken: String? = nil, deviceToken: String? = nil, pushChannelId: String? = nil) {
        self.api?.userId = userId
        self.api?.userToken = userToken
        if let token = deviceToken, let channelId = pushChannelId {
            self.registerTokenForAPNS(channelId: channelId, token: token) { result in
                
            }
        }
    }
    
    func isAuthenticated(checkUserToken: Bool = false) -> Bool {
        if checkUserToken {
            return self.api.userId?.isEmpty == false && self.api.userToken?.isEmpty == false
        }
        return self.api.userId?.isEmpty == false
    }
    
    func logout() {
        self.api?.userId = nil
        self.api?.userToken = nil
    }
    
    func getUser(completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api?.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completionHandler)
    }
    
    func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api?.decodeFromPut(User.self, path: "/users/\(userId)", body: user, then: completionHandler)
    }
}
