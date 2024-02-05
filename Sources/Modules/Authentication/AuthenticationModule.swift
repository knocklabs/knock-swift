//
//  AuthenticationModule.swift
//
//
//  Created by Matt Gardner on 1/30/24.
//

import Foundation

internal class AuthenticationModule {
        
    func signIn(userId: String, userToken: String?) async {
        Knock.shared.environment.setUserInfo(userId: userId, userToken: userToken)
        
        if let token = Knock.shared.environment.userDevicePushToken, let channelId = Knock.shared.environment.pushChannelId {
            do {
                try await Knock.shared.channelModule.registerTokenForAPNS(channelId: channelId, token: token)
            } catch {
                Knock.shared.logger.log(type: .warning, category: .user, message: "signIn", description: "Successfully set user, however, unable to registerTokenForAPNS as this time.")
            }
        }
        
        return
    }
    
    func signOut() async throws {
        guard let channelId = Knock.shared.environment.pushChannelId, let token = Knock.shared.environment.userDevicePushToken else {
            Knock.shared.environment.setUserInfo(userId: nil, userToken: nil)
            return
        }
        let _ = try await Knock.shared.channelModule.unregisterTokenForAPNS(channelId: channelId, token: token)
        Knock.shared.environment.setUserInfo(userId: nil, userToken: nil)
        return
    }
}

public extension Knock {

    func isAuthenticated(checkUserToken: Bool = false) -> Bool {
        let isUser = Knock.shared.environment.userId?.isEmpty == false
        if checkUserToken {
            return isUser && Knock.shared.environment.userToken?.isEmpty == false
        }
        return isUser
    }
    
    /**
     Set the current credentials for the user and their access token.
      Will also registerAPNS device token if set previously.
     You should consider using this in areas where you update your local user's state
     */
    func signIn(userId: String, userToken: String?) async {
        await authenticationModule.signIn(userId: userId, userToken: userToken)
    }
    
    func signIn(userId: String, userToken: String?, completionHandler: @escaping (() -> Void)) {
        Task {
            await signIn(userId: userId, userToken: userToken)
            completionHandler()
        }
    }
    
    /**
     Clears the current user id and access token
     You should call this when your user signs out
     It will remove the current tokens used for this user in Courier so they do not receive pushes they should not get
     */
    func signOut() async throws {
        try await authenticationModule.signOut()
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
