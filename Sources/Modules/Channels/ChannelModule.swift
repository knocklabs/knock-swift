//
//  ChannelModule.swift
//
//
//  Created by Matt Gardner on 1/26/24.
//

import Foundation
import OSLog
import UIKit

internal class ChannelModule {
    let channelService = ChannelService()
    
    internal var userNotificationCenter: UNUserNotificationCenter {
        get { UNUserNotificationCenter.current() }
    }

    func getUserChannelData(channelId: String) async throws -> Knock.ChannelData {
        do {
            let data = try await channelService.getUserChannelData(userId: Knock.shared.environment.getSafeUserId(), channelId: channelId)
            Knock.shared.log(type: .debug, category: .channel, message: "getUserChannelData", status: .success)
            return data
        } catch let error {
            Knock.shared.log(type: .warning, category: .channel, message: "getUserChannelData", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws -> Knock.ChannelData  {
        do {
            let data = try await channelService.updateUserChannelData(userId: Knock.shared.environment.getSafeUserId(), channelId: channelId, data: data)
            Knock.shared.log(type: .debug, category: .channel, message: "updateUserChannelData", status: .success)
            return data
        } catch let error {
            Knock.shared.log(type: .warning, category: .channel, message: "updateUserChannelData", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    private func registerOrUpdateTokenIfNeeded(
        newToken: String,
        newChannelId: String,
        existingChannelData: Knock.ChannelData?
    ) async throws -> Knock.ChannelData {
        var tokens: [String] = []
        if let existingChannelData = existingChannelData {
            guard let preparedTokens = await prepareTokenDataForRegistration(newToken: newToken, newChannelId: newChannelId, existingChannelData: existingChannelData) else {
                return existingChannelData
            }
            tokens = preparedTokens
        } else {
            tokens = [newToken]
        }
                
        let data: AnyEncodable = ["tokens": tokens]
        let channelData = try await updateUserChannelData(channelId: newChannelId, data: data)
        
        await Knock.shared.environment.setPushChannelId(newChannelId)
        await Knock.shared.environment.setDeviceToken(newToken)
        
        Knock.shared.log(type: .debug, category: .pushNotification, message: "registerOrUpdateToken", status: .success)
        return channelData
    }
    
    internal func prepareTokenDataForRegistration(
        newToken: String,
        newChannelId: String,
        existingChannelData: Knock.ChannelData?
    ) async -> [String]? {
        
        let previousToken: String? = await Knock.shared.environment.getDeviceToken()
        let previousChannelId: String? = await Knock.shared.environment.getPushChannelId()
        
        // Attempt to extract existing tokens, default to an empty array if none are found
        var existingTokens = existingChannelData?.data?["tokens"]?.value as? [String] ?? []
        
        // Check if the old token exists, needs to be removed, and if the channel IDs match
        if let previousToken = previousToken, previousToken != newToken, previousChannelId == newChannelId {
            existingTokens.removeAll { $0 == previousToken }
        }
        
        // Add the new token if it's not already in the list, otherwise return nil
        guard !existingTokens.contains(newToken) else {
            return nil
        }
        
        existingTokens.append(newToken)
        
        return existingTokens
    }
    
    func registerTokenForAPNS(channelId: String, token: String) async throws -> Knock.ChannelData {
        do {
            let channelData = try await getUserChannelData(channelId: channelId)
            let newData = try await registerOrUpdateTokenIfNeeded(newToken: token, newChannelId: channelId, existingChannelData: channelData)
            return newData
        } catch let userIdError as Knock.KnockError where userIdError == Knock.KnockError.userIdNotSetError {
            Knock.shared.log(type: .warning, category: .pushNotification, message: "ChannelId and deviceToken were saved. However, we cannot register for APNS until you have have called Knock.signIn().")
            throw userIdError
        } catch let networkError as Knock.NetworkError where networkError.code == 404 {
            // No data registered on that channel for that user, we'll create a new record
            return try await registerOrUpdateTokenIfNeeded(newToken: token, newChannelId: channelId, existingChannelData: nil)
        }
    }
    
    func unregisterTokenForAPNS(channelId: String, token: String) async throws -> Knock.ChannelData {
        do {
            let channelData = try await getUserChannelData(channelId: channelId)
            guard let data = channelData.data, let tokens = data["tokens"]?.value as? [String] else {
                // No valid tokens array found.
                Knock.shared.log(type: .warning, category: .pushNotification, message: "unregisterTokenForAPNS", description: "Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId.")
                return channelData
            }
            
            if tokens.contains(token) {
                let newTokensSet = Set(tokens).subtracting([token])
                let newTokens = Array(newTokensSet)
                let data: AnyEncodable = [
                    "tokens": newTokens
                ]
                let updateData = try await updateUserChannelData(channelId: channelId, data: data)
                Knock.shared.log(type: .debug, category: .pushNotification, message: "unregisterTokenForAPNS", status: .success)
                return updateData
            } else {
                Knock.shared.log(type: .warning, category: .pushNotification, message: "unregisterTokenForAPNS", description: "Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId.")
                return channelData
            }
        } catch {
            if let networkError = error as? Knock.NetworkError, networkError.code == 404 {
                // No data registered on that channel for that user
                Knock.shared.log(type: .warning, category: .pushNotification, message: "unregisterTokenForAPNS", description: "Could not unregister user from channel \(channelId). Reason: User doesn't have any channel data associated to the provided channelId.")
                return .init(channel_id: channelId, data: [:])
            } else {
                // Unknown error. Could be network or server related. Try again.
                Knock.shared.log(type: .error, category: .pushNotification, message: "unregisterTokenForAPNS", description: "Could not unregister user from channel \(channelId)", status: .fail, errorMessage: error.localizedDescription)
                throw error
            }
        }
    }
}

public extension Knock {
    
    /**
     Retrieves the channel data for the current user on the channel specified.
     https://docs.knock.app/reference#get-user-channel-data#get-user-channel-data
     
     - Parameters:
        - channelId: The id of the Knock channel to lookup.
     */
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
        - channelId: The id of the Knock channel to lookup
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
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. 
     This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns.
     If the data does not exists or the token is missing from the array, it's added.
     If the new token differs from the last token that was used on the device, the old token will be unregistered.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
          
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
    
    /**
     Convenience method to determine whether or not the user is allowing Push Notifications for the app.
     */
    func getNotificationPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        channelModule.userNotificationCenter.getNotificationSettings(completionHandler: { settings in
            completion(settings.authorizationStatus)
        })
    }
    
    func getNotificationPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await channelModule.userNotificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    /**
     Convenience method to request Push Notification permissions for the app.
     */
    func requestNotificationPermission(options: UNAuthorizationOptions = [.sound, .badge, .alert], completion: @escaping (UNAuthorizationStatus) -> Void) {
        channelModule.userNotificationCenter.requestAuthorization(
            options: options,
            completionHandler: { _, _ in
                self.getNotificationPermissionStatus { permission in
                    completion(permission)
                }
            }
        )
    }
    
    func requestNotificationPermission(options: UNAuthorizationOptions = [.sound, .badge, .alert]) async throws -> UNAuthorizationStatus {
        try await channelModule.userNotificationCenter.requestAuthorization(options: options)
        return await getNotificationPermissionStatus()
    }
}
