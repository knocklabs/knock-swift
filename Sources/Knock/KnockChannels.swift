//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation
import AnyCodable
import OSLog

public extension Knock {
    // MARK: Channels
    
    struct ChannelData: Codable {
        public let channel_id: String
        public let data: [String: AnyCodable]? // GenericData
    }
    
    func getUserChannelData(channelId: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        self.api.decodeFromGet(ChannelData.self, path: "/users/\(userId)/channel_data/\(channelId)", queryItems: nil, then: completionHandler)
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
        self.api.decodeFromPut(ChannelData.self, path: "/users/\(userId)/channel_data/\(channelId)", body: payload, then: completionHandler)
    }
    
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
        let tokenParts = token.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let tokenString = tokenParts.joined()
        
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
        let logger = Logger(subsystem: "app.knock.sdk", category: "KnockChannels")
        
        getUserChannelData(channelId: channelId) { result in
            switch result {
            case .failure(_):
                // there's no data registered on that channel for that user, we'll create a new record
                logger.notice("there's no data registered on that channel for that user, we'll create a new record")
                let data: AnyEncodable = [
                    "tokens": [token]
                ]
                self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
            case .success(let channelData):
                guard let data = channelData.data else {
                    // we don't have data for that channel for that user, we'll create a new record
                    logger.notice("we don't have data for that channel for that user, we'll create a new record")
                    let data: AnyEncodable = [
                        "tokens": [token]
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                    return
                }
                
                guard var tokens = data["tokens"]?.value as? [String] else {
                    // we don't have an array of valid tokens so we'll register a new one
                    logger.notice("we don't have an array of valid tokens so we'll register a new one")
                    let data: AnyEncodable = [
                        "tokens": [token]
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                    return
                }
                
                if tokens.contains(token) {
                    // we already have the token registered
                    logger.notice("we already have the token registered")
                    completionHandler(.success(channelData))
                }
                else {
                    // we need to register the token
                    logger.notice("we need to register the token")
                    tokens.append(token)
                    let data: AnyEncodable = [
                        "tokens": tokens
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                }
            }
        }
    }
}
