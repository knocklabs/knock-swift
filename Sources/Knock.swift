//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import SwiftUI
import OSLog

// Knock client SDK.
public class Knock {
    internal static let clientVersion = "1.2.7"
    
    public static var shared: Knock = Knock()
    
    public var feedManager: FeedManager?
    
    internal let environment = KnockEnvironment()
    internal lazy var authenticationModule = AuthenticationModule()
    internal lazy var userModule = UserModule()
    internal lazy var preferenceModule = PreferenceModule()
    internal lazy var messageModule = MessageModule()
    internal lazy var channelModule = ChannelModule()
    internal lazy var logger = KnockLogger()
    
    /**
    Sets up the shared Knock instance. Make sure to call this as soon as you can. Preferrably in your AppDelegate.

     - Parameters:
        - publishableKey: Your public API key
        - pushChannelId: [optional] The Knock APNS channel id that you plan to use within your app
        - options: [optional] Options for customizing the Knock instance
     */
    public func setup(publishableKey: String, pushChannelId: String?, options: Knock.KnockStartupOptions? = nil) async throws {
        logger.loggingDebugOptions = options?.loggingOptions ?? .errorsOnly
        try await environment.setPublishableKey(key: publishableKey)
        await environment.setBaseUrl(baseUrl: options?.hostname)
        await environment.setPushChannelId(pushChannelId)
    }
    
    @available(*, deprecated, message: "Use async setup() method instead for safer handling.")
    public func setup(publishableKey: String, pushChannelId: String?, options: Knock.KnockStartupOptions? = nil) throws {
        logger.loggingDebugOptions = options?.loggingOptions ?? .errorsOnly
        Task {
            try await environment.setPublishableKey(key: publishableKey)
            await environment.setBaseUrl(baseUrl: options?.hostname)
            await environment.setPushChannelId(pushChannelId)
        }
    }
    
    /**
     Reset the current Knock instance entirely.
     After calling this, you will need to setup and signin again.
     */
    public func resetInstanceCompletely() {
        Knock.shared = Knock()
    }
}

public extension Knock {
    struct KnockStartupOptions {
        public init(hostname: String? = nil, loggingOptions: LoggingOptions = .errorsOnly) {
            self.hostname = hostname
            self.loggingOptions = loggingOptions
        }
        var hostname: String?
        var loggingOptions: LoggingOptions
    }
    
    enum LoggingOptions {
        case errorsOnly
        case errorsAndWarningsOnly
        case verbose
        case none
    }
}
