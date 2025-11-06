//
//  KnockEnvironment.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal actor KnockEnvironment {
    static let defaultBaseUrl: String = "https://api.knock.app"
    
    private let defaults = UserDefaults.standard
    private let userDevicePushTokenKey = "knock_push_device_token"
    private let previousPushTokensKey = "knock_previous_push_token"

    private var userId: String?
    private var userToken: String?
    private var publishableKey: String?
    private var pushChannelId: String?
    private var baseUrl: String = defaultBaseUrl
    
    // BaseURL
    
    func getBaseUrl() -> String {
        baseUrl
    }
    
    func setBaseUrl(baseUrl: String?) {
        self.baseUrl = "\(baseUrl ?? KnockEnvironment.defaultBaseUrl)"
    }
    
    //UserId
    
    func setUserInfo(userId: String?, userToken: String?) {
        self.userId = userId
        self.userToken = userToken
    }
    
    func getUserId() -> String? {
        userId
    }
    
    func getSafeUserId() throws -> String {
        guard let id = userId else {
            throw Knock.KnockError.userIdNotSetError
        }
        return id
    }
    
    func getUserToken() -> String? {
        userToken
    }
    
    func getSafeUserToken() throws -> String? {
        guard let token = userToken else {
            throw Knock.KnockError.userTokenNotSet
        }
        return token
    }
    
    // Publishable Key
    func setPublishableKey(key: String) throws {
        guard key.hasPrefix("sk_") == false else {
            let error = Knock.KnockError.wrongKeyError
            Knock.shared.log(type: .error, category: .general, message: "setPublishableKey", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
        self.publishableKey = key
    }
    
    func getPublishableKey() -> String? {
        publishableKey
    }
    
    func getSafePublishableKey() throws -> String {
        guard let id = publishableKey else {
            throw Knock.KnockError.knockNotSetup
        }
        return id
    }
    
    // PushChannelId
    func setPushChannelId(_ newChannelId: String?) {
        self.pushChannelId = newChannelId
    }
    
    func getPushChannelId() -> String? {
        self.pushChannelId
    }
    
    func getSafePushChannelId() throws -> String {
        guard let id = pushChannelId else {
            throw Knock.KnockError.pushChannelIdNotSetError
        }
        return id
    }
    
    // APNS Device Token
    public func setDeviceToken(_ token: String?) async {
        let previousTokens = getPreviousPushTokens()
        if let token = token, !previousTokens.contains(token) {
            // Append new token to the list of previous tokens only if it's unique
            // We are storing these old tokens so that we can ensure they get unregestired.
            setPreviousPushTokens(tokens: previousTokens + [token])
        }
        
        // Update the current device token
        defaults.set(token, forKey: userDevicePushTokenKey)
    }
    
    func getDeviceToken() -> String? {
        defaults.string(forKey: userDevicePushTokenKey)
    }
    
    func getSafeDeviceToken() throws -> String {
        guard let token = getDeviceToken() else {
            throw Knock.KnockError.devicePushTokenNotSet
        }
        return token
    }
    
    func setPreviousPushTokens(tokens: [String]) {
        defaults.set(tokens, forKey: previousPushTokensKey)
    }
    func getPreviousPushTokens() -> [String] {
        defaults.array(forKey: previousPushTokensKey) as? [String] ?? []
    }
}

public extension Knock {

    func setUserInfo(userId: String?, userToken: String?) async {
        await environment.setUserInfo(userId: userId, userToken: userToken)
    }

    func setUserInfo(userId: String?, userToken: String?, completion: @escaping () -> Void) {
        Task {
            await environment.setUserInfo(userId: userId, userToken: userToken)
            completion()
        }
    }

    /// Returns the userId that was set from the Knock.shared.signIn method.
    func getUserId() async -> String? {
        await environment.getUserId()
    }

    func getUserId(completion: @escaping (String?) -> Void) {
        Task {
            completion(await environment.getUserId())
        }
    }

    func getDeviceToken() async -> String? {
        await environment.getDeviceToken()
    }

    func getDeviceToken(completion: @escaping (String?) -> Void) {
        Task {
            completion(await environment.getDeviceToken())
        }
    }

    func getPushChannelId() async -> String? {
        await environment.getPushChannelId()
    }

    func getPushChannelId(completion: @escaping (String?) -> Void) {
        Task {
            completion(await environment.getPushChannelId())
        }
    }
}
