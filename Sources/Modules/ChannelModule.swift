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
    let channelService: ChannelService = ChannelService()

    internal var userNotificationCenter: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func getUserChannelData(channelId: String) async throws -> Knock.ChannelData {
        do {
            let channelData: Knock.ChannelData = try await channelService.getUserChannelData(
                userId: Knock.shared.environment.getSafeUserId(), channelId: channelId)
            Knock.shared.log(
                type: .debug, category: .channel, message: "getUserChannelData", status: .success)
            return channelData
        } catch let error {
            Knock.shared.log(
                type: .warning, category: .channel, message: "getUserChannelData", status: .fail,
                errorMessage: error.localizedDescription)
            throw error
        }
    }

    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws
        -> Knock.ChannelData
    {
        do {
            let channelData: Knock.ChannelData = try await channelService.updateUserChannelData(
                userId: Knock.shared.environment.getSafeUserId(), channelId: channelId, data: data)
            Knock.shared.log(
                type: .debug, category: .channel, message: "updateUserChannelData", status: .success
            )
            return channelData
        } catch let error {
            Knock.shared.log(
                type: .warning, category: .channel, message: "updateUserChannelData", status: .fail,
                errorMessage: error.localizedDescription)
            throw error
        }
    }

    func registerTokenForAPNS(channelId: String?, token: String) async throws -> Knock.ChannelData {
        // Store or update the token locally immediately
        await Knock.shared.environment.setDeviceToken(token)

        // Ensure user is authenticated
        guard let channelId: String = channelId, await Knock.shared.isAuthenticated() else {
            // Exit if not authenticated; token is stored for later registration
            Knock.shared.log(
                type: .warning, category: .pushNotification,
                message:
                    "ChannelId and deviceToken were saved. However, we cannot register for APNS until you have have called Knock.signIn()."
            )
            return .init(
                channel_id: "",
                data: ["tokens": [token], "devices": [buildDeviceObject(token: token)]])
        }

        await Knock.shared.environment.setPushChannelId(channelId)

        // Now proceed to prepare and register the token on the server
        return try await prepareToRegisterDeviceOnServer(token: token, channelId: channelId)
    }

    func unregisterTokenForAPNS(channelId: String, token: String) async throws -> Knock.ChannelData
    {
        do {
            let channelData: Knock.ChannelData = try await getUserChannelData(channelId: channelId)
            let previousTokensFromDevice: [String] = await Knock.shared.environment
                .getPreviousPushTokens()

            guard
                let currentDevicesFromServer = channelData.data?["devices"]?.value
                    as? [Knock.Device]
            else {
                // No valid tokens array found.
                Knock.shared.log(
                    type: .warning, category: .pushNotification, message: "unregisterTokenForAPNS",
                    description:
                        "Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId."
                )
                return channelData
            }

            var updatedDevices = filterTokensOutFromDevices(
                devices: currentDevicesFromServer, targetTokens: previousTokensFromDevice + [token])

            if updatedDevices != currentDevicesFromServer {
                let updateData: Knock.ChannelData = try await updateUserChannelData(
                    channelId: channelId,
                    data: [
                        "devices": updatedDevices
                    ])

                await Knock.shared.environment.setPreviousPushTokens(tokens: [])

                Knock.shared.log(
                    type: .debug, category: .pushNotification, message: "unregisterTokenForAPNS",
                    status: .success)
                return updateData
            } else {
                Knock.shared.log(
                    type: .debug, category: .pushNotification, message: "unregisterTokenForAPNS",
                    description:
                        "Could not unregister user from channel \(channelId). Reason: User doesn't have any device tokens associated to the provided channelId."
                )
                return channelData
            }
        } catch {
            if let networkError = error as? Knock.NetworkError, networkError.code == 404 {
                // No data registered on that channel for that user
                Knock.shared.log(
                    type: .debug, category: .pushNotification, message: "unregisterTokenForAPNS",
                    description:
                        "Could not unregister user from channel \(channelId). Reason: User doesn't have any channel data associated to the provided channelId."
                )
                return .init(channel_id: channelId, data: [:])
            } else {
                // Unknown error. Could be network or server related. Try again.
                Knock.shared.log(
                    type: .error, category: .pushNotification, message: "unregisterTokenForAPNS",
                    description: "Could not unregister user from channel \(channelId)",
                    status: .fail, errorMessage: error.localizedDescription)
                throw error
            }
        }
    }

    private func prepareToRegisterDeviceOnServer(token: String, channelId: String)
        async throws -> Knock.ChannelData
    {
        do {
            let channelData: Knock.ChannelData = try await getUserChannelData(channelId: channelId)
            let devices = channelData.data?["devices"]?.value as? [Knock.Device] ?? []

            let previousTokens: [String] = await Knock.shared.environment.getPreviousPushTokens()

            var newDevices = filterTokensOutFromDevices(
                devices: devices,
                targetTokens: previousTokens
            )
            newDevices = addTokenToDevices(
                devices: newDevices,
                newToken: token
            )

            if newDevices != devices {
                return try await registerNewDevicesDataOnServer(
                    devices: newDevices, channelId: channelId)
            } else {
                return channelData
            }
        } catch let userIdError as Knock.KnockError
            where userIdError == Knock.KnockError.userIdNotSetError
        {
            // User is not signed in. This should be caught earlier, but including it here as well just in case.
            Knock.shared.log(
                type: .warning, category: .pushNotification,
                message:
                    "ChannelId and deviceToken were saved. However, we cannot register for APNS until you have have called Knock.signIn()."
            )
            return .init(channel_id: channelId, data: ["tokens": [token]])
        } catch let networkError as Knock.NetworkError where networkError.code == 404 {
            // No data registered on that channel for that user, we'll create a new record
            return try await registerNewDevicesDataOnServer(
                devices: [buildDeviceObject(token: token)], channelId: channelId)
        } catch {
            Knock.shared.log(
                type: .error, category: .pushNotification, message: "Failed to register token",
                errorMessage: error.localizedDescription)
            throw error
        }
    }

    internal func buildDeviceObject(token: String) -> Knock.Device {
        return Knock.Device(
            token: token,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }

    internal func filterTokensOutFromDevices(
        devices: [Knock.Device],
        targetTokens: [String]
    ) -> [Knock.Device] {
        var filteredDevices: [Knock.Device] = devices
        filteredDevices.removeAll(where: { targetTokens.contains($0.token) })
        return filteredDevices
    }

    internal func addTokenToDevices(
        devices: [Knock.Device],
        newToken: String
    ) -> [Knock.Device] {
        var updatedDevices: [Knock.Device] = devices
        if !updatedDevices.contains(where: { $0.token == newToken }) {
            updatedDevices.append(buildDeviceObject(token: newToken))
        }
        return updatedDevices
    }

    private func registerNewDevicesDataOnServer(devices: [Knock.Device], channelId: String)
        async throws -> Knock.ChannelData
    {
        let data: AnyEncodable = ["devices": devices]
        let channelData: Knock.ChannelData = try await updateUserChannelData(
            channelId: channelId, data: data)

        // Clear previous tokens upon successful update
        await Knock.shared.environment.setPreviousPushTokens(tokens: [])

        Knock.shared.log(
            type: .debug, category: .pushNotification, message: "Token registered on server",
            status: .success)
        return channelData
    }

}

public extension Knock {

    /**
     Retrieves the channel data for the current user on the channel specified.
     https://docs.knock.app/reference#get-user-channel-data
    
     - Parameters:
        - channelId: The id of the Knock channel to lookup.
     */
    func getUserChannelData(channelId: String) async throws -> ChannelData {
        try await self.channelModule.getUserChannelData(channelId: channelId)
    }

    func getUserChannelData(
        channelId: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
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
    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws
        -> ChannelData
    {
        try await self.channelModule.updateUserChannelData(channelId: channelId, data: data)
    }

    func updateUserChannelData(
        channelId: String, data: AnyEncodable,
        completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
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
    Returns the apnsDeviceToken that was set from the Knock.shared.registerTokenForAPNS.
    If you use our KnockAppDelegate, the token registration will be handled for you automatically.
    */
    func getApnsDeviceToken() async -> String? {
        await environment.getDeviceToken()
    }

    func getApnsDeviceToken(completion: @escaping (String?) -> Void) {
        Task {
            completion(await environment.getDeviceToken())
        }
    }

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
    func registerTokenForAPNS(channelId: String?, token: String) async throws -> ChannelData
    {
        return try await self.channelModule.registerTokenForAPNS(channelId: channelId, token: token)
    }

    func registerTokenForAPNS(
        channelId: String?, token: String,
        completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
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
        return try await self.channelModule.registerTokenForAPNS(
            channelId: channelId, token: tokenString)
    }

    func registerTokenForAPNS(
        channelId: String, token: Data,
        completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        registerTokenForAPNS(
            channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }

    /**
     Unregisters the current deviceId associated to the user so that the device will no longer  receive remote push notifications for the provided channelId.
    
     - Parameters:
        - channelId: the id of the APNS channel in Knock
        - token: the APNS device token as a `String`
     */
    func unregisterTokenForAPNS(channelId: String, token: String) async throws -> ChannelData
    {
        return try await self.channelModule.unregisterTokenForAPNS(
            channelId: channelId, token: token)
    }

    func unregisterTokenForAPNS(
        channelId: String, token: String,
        completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
        Task {
            do {
                let channelData = try await unregisterTokenForAPNS(
                    channelId: channelId, token: token)
                completionHandler(.success(channelData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }

    func unregisterTokenForAPNS(channelId: String, token: Data) async throws -> ChannelData {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        return try await self.channelModule.unregisterTokenForAPNS(
            channelId: channelId, token: tokenString)
    }

    func unregisterTokenForAPNS(
        channelId: String, token: Data,
        completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)
    ) {
        // 1. Convert device token to string
        let tokenString = Knock.convertTokenToString(token: token)
        unregisterTokenForAPNS(
            channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }

    /**
     Convenience method to determine whether or not the user is allowing Push Notifications for the app.
     */
    func getNotificationPermissionStatus(
        completion: @escaping (UNAuthorizationStatus) -> Void
    ) {
        channelModule.userNotificationCenter.getNotificationSettings(completionHandler: {
            settings in
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
    func requestNotificationPermission(
        options: UNAuthorizationOptions = [.sound, .badge, .alert],
        completion: @escaping (UNAuthorizationStatus) -> Void
    ) {
        channelModule.userNotificationCenter.requestAuthorization(
            options: options,
            completionHandler: { _, _ in
                self.getNotificationPermissionStatus { permission in
                    completion(permission)
                }
            }
        )
    }

    func requestNotificationPermission(
        options: UNAuthorizationOptions = [.sound, .badge, .alert]
    ) async throws -> UNAuthorizationStatus {
        try await channelModule.userNotificationCenter.requestAuthorization(options: options)
        return await getNotificationPermissionStatus()
    }

    /**
     Convenience method to request Push Notification permissions for the app, and then, if successfull, registerForRemoteNotifications in order to get a device token.
     */
    func requestAndRegisterForPushNotifications() {
        Knock.shared.requestNotificationPermission { status in
            if status != .denied {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
