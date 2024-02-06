//
//  AuthenticationModule.swift
//
//
//  Created by Matt Gardner on 1/30/24.
//

import Foundation

internal class AuthenticationModule {
    
    func signIn(userId: String, userToken: String?) async {
        await Knock.shared.environment.setUserInfo(userId: userId, userToken: userToken)
        
        if let token = await Knock.shared.environment.getDeviceToken(), let channelId = await Knock.shared.environment.getPushChannelId() {
            do {
                let _ = try await Knock.shared.channelModule.registerTokenForAPNS(channelId: channelId, token: token)
            } catch {
                Knock.shared.logger.log(type: .warning, category: .user, message: "signIn", description: "Successfully set user, however, unable to registerTokenForAPNS as this time.")
            }
        }
        
        return
    }
    
    func signOut() async throws {
        guard let channelId = await Knock.shared.environment.getPushChannelId(), let token = await Knock.shared.environment.getDeviceToken() else {
            await clearDataForSignOut()
            return
        }
        
        let _ = try await Knock.shared.channelModule.unregisterTokenForAPNS(channelId: channelId, token: token)
        await clearDataForSignOut()
        return
    }
    
    func clearDataForSignOut() async {
        await Knock.shared.environment.setUserInfo(userId: nil, userToken: nil)
    }
}

public extension Knock {
    /**
     Convienience method to determine if a user is currently authenticated for the Knock instance.
     */
    func isAuthenticated(checkUserToken: Bool = false) async -> Bool {
        let isUser = await Knock.shared.environment.getUserId()?.isEmpty == false
        if checkUserToken {
            let hasToken = await Knock.shared.environment.getUserToken()?.isEmpty == false
            return isUser && hasToken
        }
        return isUser
    }
    
    /**
     Sets the userId and userToken for the current Knock instance.
     If the device token and pushChannelId were set previously, this will also attempt to register the token to the user that is being signed in.
     This does not get the user from the database nor does it return the full User object.
     You should consider using this in areas where you update your local user's state.
     
     - Parameters:
        - userId: The id of the Knock channel to lookup.
        - userToken: [optional] The id of the Knock channel to lookup.
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
     Sets the userId and userToken for the current Knock instance back to nil.
     If the device token and pushChannelId were set previously, this will also attempt to unregister the token to the user that is being signed out so they don't receive pushes they shouldn't get.
     You should call this when your user signs out
     - Note: This will not clear the device token so that it can be accesed for the next user to login.
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
