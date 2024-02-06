//
//  KnockEnvironment.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal class KnockEnvironment {
    static let defaultBaseUrl: String = "https://api.knock.app"
    private let defaults = UserDefaults.standard
    private let userDevicePushTokenKey = "knock_push_device_token"
    private let pushChannelIdKey = "knock_push_channel_id"

    private(set) var userId: String?
    private(set) var userToken: String?
    private(set) var publishableKey: String?
    private(set) var baseUrl: String = defaultBaseUrl
    
    var userDevicePushToken: String? {
        get {
            defaults.string(forKey: userDevicePushTokenKey)
        }
        set {
            defaults.set(newValue, forKey: userDevicePushTokenKey)
        }
    }
    
    var pushChannelId: String? {
        get {
            defaults.string(forKey: pushChannelIdKey)
        }
        set {
            defaults.set(newValue, forKey: pushChannelIdKey)
        }
    }

    func setPublishableKey(key: String) throws {
        guard key.hasPrefix("sk_") == false else {
            let error = Knock.KnockError.wrongKeyError
            Knock.shared.log(type: .error, category: .general, message: "setPublishableKey", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
        self.publishableKey = key
    }
    
    func setUserInfo(userId: String?, userToken: String?) {
        self.userId = userId
        self.userToken = userToken
    }
    
    func setBaseUrl(baseUrl: String?) {
        self.baseUrl = "\(baseUrl ?? KnockEnvironment.defaultBaseUrl)"
    }
    
    func getSafeUserId() throws -> String {
        guard let id = userId else {
            throw Knock.KnockError.userIdNotSetError
        }
        return id
    }
    
    func getSafePublishableKey() throws -> String {
        guard let id = publishableKey else {
            throw Knock.KnockError.knockNotSetup
        }
        return id
    }
}
