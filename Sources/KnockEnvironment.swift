//
//  KnockEnvironment.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal class KnockEnvironment {
    static let shared = KnockEnvironment()
    
    static let defaultBaseUrl: String = "https://api.knock.app"
    
    private(set) var userId: String?
    private(set) var userToken: String?
    private(set) var userDevicePushToken: String?
    private(set) var pushChannelId: String?
    private(set) var publishableKey: String = ""
    private(set) var baseUrl: String = ""

    func setPublishableKey(key: String) throws {
        guard key.hasPrefix("sk_") == false else {
            let error = Knock.KnockError.runtimeError("You are using your secret API key on the client. Please use the public key.")
            KnockLogger.log(type: .error, category: .general, message: "setPublishableKey", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
        self.publishableKey = key
    }
    
    func setPushInformation(channelId: String?, deviceToken: String?) {
        self.pushChannelId = channelId
        self.userDevicePushToken = deviceToken
    }
    
    func setUserInfo(userId: String?, userToken: String?) {
        self.userId = userId
        self.userToken = userToken
    }
    
    func setBaseUrl(baseUrl: String?) {
        self.baseUrl = "\(baseUrl ?? KnockEnvironment.defaultBaseUrl)"
    }
    
    func resetEnvironment() {
        setUserInfo(userId: nil, userToken: nil)
        setPushInformation(channelId: nil, deviceToken: nil)
    }
    
    func getSafeUserId() throws -> String {
        guard let id = KnockEnvironment.shared.userId else {
            throw Knock.KnockError.userIdError
        }
        return id
    }
}
