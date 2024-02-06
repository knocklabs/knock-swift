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

    private var userId: String?
    private var userToken: String?
    private var publishableKey: String?
    private var pushChannelId: String?
    private var baseUrl: String = defaultBaseUrl
    
    private var userDevicePushToken: String? {
        get {
            defaults.string(forKey: userDevicePushTokenKey)
        }
        set {
            defaults.set(newValue, forKey: userDevicePushTokenKey)
        }
    }
    
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
    func setDeviceToken(_ token: String) {
        userDevicePushToken = token
    }
    
    func getDeviceToken() -> String? {
        userDevicePushToken
    }
    
    func getSafeDeviceToken() throws -> String {
        guard let token = userDevicePushToken else {
            throw Knock.KnockError.devicePushTokenNotSet
        }
        return token
    }
}
