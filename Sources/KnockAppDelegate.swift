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
    
    private let logger = Logger(subsystem: "knock-swift", category: "KnockAppDelegate")
    
    // MARK: Init
    
    override init() {
        super.init()
        
        // Register to ensure device token can be fetched
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        
    }
    
    // MARK: Launching
    
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    // MARK: Notifications
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.debug("userNotificationCenter willPresent notification: \(notification)")

        let userInfo = notification.request.content.userInfo
        
        let presentationOptions = pushNotificationDeliveredInForeground(userInfo: userInfo)
        completionHandler(presentationOptions)
    }
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.debug("didReceiveNotificationResponse: \(response)")
        
        let userInfo = response.notification.request.content.userInfo
        
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            pushNotificationDismissed(userInfo: userInfo)
        } else {
            pushNotificationTapped(userInfo: userInfo)
        }
        completionHandler()
    }
    
    // MARK: Token Management
    
    open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register for notifications: \(error.localizedDescription)")
    }
    
    open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.debug("Successfully registered for notifications!")
        
        // 1. Convert device token to string
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        // 2. Print device token to use for PNs payloads
        logger.debug("Device Token: \(token)")
                
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: "device_push_token")
        deviceTokenDidChange(apnsToken: token, isDebugging: isDebuggerAttached)
//        self.pushToken = token
    }
    
    // MARK: Functions
    
    open func deviceTokenDidChange(apnsToken: String, isDebugging: Bool) {}
    
    open func pushNotificationDeliveredInForeground(userInfo: [AnyHashable : Any]) -> UNNotificationPresentationOptions { return [] }
    
    open func pushNotificationTapped(userInfo: [AnyHashable : Any]) {}
    
    open func pushNotificationDismissed(userInfo: [AnyHashable : Any]) {}
}
