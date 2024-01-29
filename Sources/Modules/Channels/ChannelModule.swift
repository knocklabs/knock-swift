//
//  ChannelModule.swift
//
//
//  Created by Matt Gardner on 1/26/24.
//

import Foundation
import OSLog

internal class ChannelModule {
    let channelService = ChannelService()
    private let logger: Logger =  Logger(subsystem: Knock.loggingSubsytem, category: "ChannelModule")

    func getUserChannelData(channelId: String) async throws -> Knock.ChannelData {
        try await channelService.getUserChannelData(channelId: channelId)
    }
    
    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws -> Knock.ChannelData  {
        try await channelService.updateUserChannelData(channelId: channelId, data: data)
    }
    
    private func registerOrUpdateToken(token: String, channelId: String, existingTokens: [String]?) async throws -> Knock.ChannelData {
        var tokens = existingTokens ?? []
        if !tokens.contains(token) {
            tokens.append(token)
        }
        
        let data: AnyEncodable = ["tokens": tokens]
        return try await updateUserChannelData(channelId: channelId, data: data)
    }
    
    func registerTokenForAPNS(channelId: String, token: String) async throws -> Knock.ChannelData {
        do {
            
            let channelData = try await getUserChannelData(channelId: channelId)
            guard let data = channelData.data, let tokens = data["tokens"]?.value as? [String] else {
                // No valid tokens array found, register a new one
                return try await registerOrUpdateToken(token: token, channelId: channelId, existingTokens: nil)
            }
            
            if tokens.contains(token) {
                // Token already registered
                return channelData
            } else {
                // Register the new token
                return try await registerOrUpdateToken(token: token, channelId: channelId, existingTokens: tokens)
            }
        } catch {
            // No data registered on that channel for that user, we'll create a new record
            return try await registerOrUpdateToken(token: token, channelId: channelId, existingTokens: nil)
        }
    }
    
    func unregisterTokenForAPNS(channelId: String, token: String) async throws -> Knock.ChannelData {
        do {
            let channelData = try await getUserChannelData(channelId: channelId)
            guard let data = channelData.data, let tokens = data["tokens"]?.value as? [String] else {
                // No valid tokens array found.
                self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId.")
                return channelData
            }
            
            if tokens.contains(token) {
                let newTokensSet = Set(tokens).subtracting([token])
                let newTokens = Array(newTokensSet)
                let data: AnyEncodable = [
                    "tokens": newTokens
                ]
                return try await updateUserChannelData(channelId: channelId, data: data)
            } else {
                self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens that match the token provided.")
                return channelData
            }
        } catch {
            if let networkError = error as? Knock.NetworkError, networkError.code == 404 {
                // No data registered on that channel for that user
                self.logger.warning("[Knock] Could not unregister user from channel \(channelId). Reason: User doesn't have any channel data associated to the provided channelId.")
                return .init(channel_id: channelId, data: [:])
            } else {
                // Unknown error. Could be network or server related. Try again.
                self.logger.error("[Knock] Could not unregister user from channel \(channelId). Please try again. Reason: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

public extension Knock {
    
    func getUserChannelData(channelId: String) async throws -> ChannelData {
        try await self.channelModule.getUserChannelData(channelId: channelId)
    }

    func getUserChannelData(channelId: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        Task {
            do {
                let channelData = try await getUserChannelData(channelId: channelId)
                completionHandler(.success(channelData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    /**
     Sets channel data for the user and the channel specified.
     
     - Parameters:
        - channelId: the id of the channel
        - data: the shape of the payload varies depending on the channel. You can learn more about channel data schemas [here](https://docs.knock.app/send-notifications/setting-channel-data#provider-data-requirements).
     */
    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws -> ChannelData {
        try await self.channelModule.updateUserChannelData(channelId: channelId, data: data)
    }

    func updateUserChannelData(channelId: String, data: AnyEncodable, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        Task {
            do {
                let channelData = try await updateUserChannelData(channelId: channelId, data: data)
                completionHandler(.success(channelData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    // Mark: Registration of APNS device tokens
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - channelId: the id of the APNS channel
        - token: the APNS device token as a `String`
     */
    func registerTokenForAPNS(channelId: String, token: String) async throws -> ChannelData {
        return try await self.channelModule.registerTokenForAPNS(channelId: channelId, token: token)
    }
    
    func registerTokenForAPNS(channelId: String, token: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        Task {
            do {
                let channelData = try await registerTokenForAPNS(channelId: channelId, token: token)
                completionHandler(.success(channelData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - channelId: the id of the APNS channel
        - token: the APNS device token as `Data`
     */
    func registerTokenForAPNS(channelId: String, token: Data) async throws -> ChannelData {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        return try await self.channelModule.registerTokenForAPNS(channelId: channelId, token: tokenString)
    }
    
    func registerTokenForAPNS(channelId: String, token: Data, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        registerTokenForAPNS(channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }
    
    
    /**
     Unregisters the current deviceId associated to the user so that the device will no longer  receive remote push notifications for the provided channelId.
     
     - Parameters:
        - channelId: the id of the APNS channel in Knock
        - token: the APNS device token as a `String`
     */
    
    func unregisterTokenForAPNS(channelId: String, token: String) async throws -> ChannelData {
        return try await self.channelModule.unregisterTokenForAPNS(channelId: channelId, token: token)
    }
    
    func unregisterTokenForAPNS(channelId: String, token: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        Task {
            do {
                let channelData = try await unregisterTokenForAPNS(channelId: channelId, token: token)
                completionHandler(.success(channelData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func unregisterTokenForAPNS(channelId: String, token: Data) async throws -> ChannelData {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        return try await self.channelModule.unregisterTokenForAPNS(channelId: channelId, token: tokenString)
    }
    
    func unregisterTokenForAPNS(channelId: String, token: Data, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        unregisterTokenForAPNS(channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }
}
