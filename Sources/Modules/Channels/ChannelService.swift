//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation
import OSLog

public extension Knock {
    private var logger: Logger {
        Logger(subsystem: Knock.loggingSubsytem, category: "ChannelService")
    }

    func getUserChannelData(channelId: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        self.api.decodeFromGet(ChannelData.self, path: "/users/\(self.safeUserId)/channel_data/\(channelId)", queryItems: nil, then: completionHandler)
    }
    
    /**
     Sets channel data for the user and the channel specified.
     
     - Parameters:
        - channelId: the id of the channel
        - data: the shape of the payload varies depending on the channel. You can learn more about channel data schemas [here](https://docs.knock.app/send-notifications/setting-channel-data#provider-data-requirements).
     */
    func updateUserChannelData(channelId: String, data: AnyEncodable, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        let payload = [
            "data": data
        ]
        self.api.decodeFromPut(ChannelData.self, path: "/users/\(self.safeUserId)/channel_data/\(channelId)", body: payload, then: completionHandler)
    }
    
    // Mark: Registration of APNS device tokens
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - channelId: the id of the APNS channel
        - token: the APNS device token as `Data`
     */
    func registerTokenForAPNS(channelId: String, token: Data, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        
        registerTokenForAPNS(channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - channelId: the id of the APNS channel
        - token: the APNS device token as a `String`
     */
    func registerTokenForAPNS(channelId: String, token: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        // Closure to handle token registration/update
        let registerOrUpdateToken = { [weak self] (existingTokens: [String]?) in
            guard let self = self else { return }
            var tokens = existingTokens ?? []
            if !tokens.contains(token) {
                tokens.append(token)
            }
            let data: AnyEncodable = ["tokens": tokens]
            self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
        }
        
        getUserChannelData(channelId: channelId) { result in
            switch result {
            case .failure(_):
                // No data registered on that channel for that user, we'll create a new record
                registerOrUpdateToken(nil)
                completionHandler(.success(ChannelData.init(channel_id: channelId, data: [:])))
            case .success(let channelData):
                guard let data = channelData.data, let tokens = data["tokens"]?.value as? [String] else {
                    // No valid tokens array found, register a new one
                    registerOrUpdateToken(nil)
                    return
                }
                
                if tokens.contains(token) {
                    // Token already registered
                    completionHandler(.success(channelData))
                } else {
                    // Register the new token
                    registerOrUpdateToken(tokens)
                }
            }
        }
    }
    
    /**
     Unregisters the current deviceId associated to the user so that the device will no longer  receive remote push notifications for the provided channelId.
     
     - Parameters:
        - channelId: the id of the APNS channel in Knock
        - token: the APNS device token as a `String`
     */
    
    func unregisterTokenForAPNS(channelId: String, token: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        getUserChannelData(channelId: channelId) { result in
            switch result {
            case .failure(let error):
                if let networkError = error as? NetworkError, networkError.code == 404 {
                    // No data registered on that channel for that user
                    self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any channel data associated to the provided channelId.")
                    completionHandler(.success(.init(channel_id: channelId, data: [:])))
                } else {
                    // Unknown error. Could be network or server related. Try again.
                    self.logger.error("[Knock] Could not unregister user from channel \(channelId). Please try again. Reason: \(error.localizedDescription)")
                    completionHandler(.failure(error))
                }
                
            case .success(let channelData):
                guard let data = channelData.data, let tokens = data["tokens"]?.value as? [String] else {
                    // No valid tokens array found.
                    self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId.")
                    completionHandler(.success(channelData))
                    return
                }
                
                if tokens.contains(token) {
                    let newTokensSet = Set(tokens).subtracting([token])
                    let newTokens = Array(newTokensSet)
                    let data: AnyEncodable = [
                        "tokens": newTokens
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                } else {
                    self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens that match the token provided.")
                    completionHandler(.success(channelData))
                }
            }
        }
    }
}
