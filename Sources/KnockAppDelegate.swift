//
//  KnockAppDelegate.swift
//
//
//  Created by Matt Gardner on 1/22/24.
//

import Foundation
import UIKit
import OSLog

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
            let channelId = Knock.shared.environment.pushChannelId

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
    
    // MARK: Convenience methods to make handling incoming push notifications simpler.
    open func deviceTokenDidChange(apnsToken: String) {}
    
    open func pushNotificationDeliveredInForeground(notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.sound, .badge, .banner]
    }
    
    open func pushNotificationTapped(userInfo: [AnyHashable : Any]) {}
        
    open func pushNotificationDeliveredSilently(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
}
