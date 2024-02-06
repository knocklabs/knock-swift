//
//  KnockAppDelegate.swift
//
//
//  Created by Matt Gardner on 1/22/24.
//

import Foundation
import UIKit
import OSLog

/**
This class serves as an optional base class designed to streamline the integration of Knock into your application. By inheriting from KnockAppDelegate in your AppDelegate, you gain automatic handling of Push Notification registration and device token management, simplifying the initial setup process for Knock's functionalities.

The class also provides a set of open helper functions that are intended to facilitate the handling of different Push Notification events such as delivery in the foreground, taps, and dismissals. These helper methods offer a straightforward approach to customizing your app's response to notifications, ensuring that you can tailor the behavior to fit your specific needs.

Override any of the provided methods to achieve further customization, allowing you to control how your application processes and reacts to Push Notifications. Additionally, by leveraging this class, you ensure that your app adheres to best practices for managing device tokens and interacting with the notification system on iOS, enhancing the overall reliability and user experience of your app's notification features.

Key Features:
- Automatic registration for remote notifications, ensuring your app is promptly set up to receive and handle Push Notifications.
- Simplified device token management, with automatic storage of the device token, facilitating easier access and use in Push Notification payloads.
- Customizable notification handling through open helper functions, allowing for bespoke responses to notification events such as foreground delivery, user taps, and dismissal actions.
- Automatic message status updates, based on Push Notification interaction.

Developers can benefit from a quick and efficient setup, focusing more on the unique aspects of their notification handling logic while relying on KnockAppDelegate for the foundational setup and management tasks.
*/

@available(iOSApplicationExtension, unavailable)
open class KnockAppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
        
    // MARK: Init
    
    public override init() {
        super.init()
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: Launching
    
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Check if launched from a notification
        if let launchOptions = launchOptions,
           let userInfo = launchOptions[.remoteNotification] as? [String: AnyObject] {
            Knock.shared.log(type: .error, category: .pushNotification, message: "pushNotificationTapped")
            pushNotificationTapped(userInfo: userInfo)
        }
        
        return true
    }
    
    // MARK: Token Management
    
    open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Knock.shared.log(type: .error, category: .pushNotification, message: "Failed to register for notifications", errorMessage: error.localizedDescription)
    }
    
    open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            let channelId = await Knock.shared.environment.getPushChannelId()

            do {
                if let id = channelId {
                    let _ = try await Knock.shared.registerTokenForAPNS(channelId: id, token: deviceToken)
                } else {
                    Knock.shared.log(type: .error, category: .pushNotification, message: "didRegisterForRemoteNotificationsWithDeviceToken", status: .fail, errorMessage: "Unable to find pushChannelId. Please set the pushChannelId with Knock.shared.setup")
                }
            } catch let error {
                Knock.shared.log(type: .error, category: .pushNotification, message: "didRegisterForRemoteNotificationsWithDeviceToken", description: "Unable to register for push notification at this time", status: .fail, errorMessage: error.localizedDescription)
            }
        }
    }
    
    // MARK: Notifications
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Knock.shared.log(type: .debug, category: .pushNotification, message: "pushNotificationDeliveredInForeground")
        let presentationOptions = pushNotificationDeliveredInForeground(notification: notification)
        completionHandler(presentationOptions)
    }
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Knock.shared.log(type: .debug, category: .pushNotification, message: "pushNotificationTapped")
        pushNotificationTapped(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    open func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Knock.shared.log(type: .debug, category: .pushNotification, message: "pushNotificationDeliveredSilently")
        pushNotificationDeliveredSilently(userInfo: userInfo, completionHandler: completionHandler)
    }
    
    // MARK: Helper Functions

    open func deviceTokenDidChange(apnsToken: String) {}
    
    open func pushNotificationDeliveredInForeground(notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.sound, .badge, .banner]
    }
    
    open func pushNotificationTapped(userInfo: [AnyHashable : Any]) {}
        
    open func pushNotificationDeliveredSilently(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
}
