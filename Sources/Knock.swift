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
    internal static let clientVersion = "1.0.0"
    
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
     Returns a new instance of the Knock Client

     - Parameters:
        - publishableKey: Your public API key
        - options: [optional] Options for customizing the Knock instance.
     */
    public func setup(publishableKey: String, pushChannelId: String?, options: Knock.KnockStartupOptions? = nil) async throws {
        logger.loggingDebugOptions = options?.loggingOptions ?? .errorsOnly
        try await environment.setPublishableKey(key: publishableKey)
        await environment.setBaseUrl(baseUrl: options?.hostname)
        await environment.setPushChannelId(pushChannelId)
    }
    
    @available(*, deprecated, message: "Use async setup() method instead")
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
        case verbose
        case none
    }
}

public extension Knock {
    /// Returns the userId that was set from the Knock.shared.signIn method.
    func getUserId() async -> String? {
        await environment.getUserId()
    }
    
    /**
    Returns the apnsDeviceToekn that was set from the Knock.shared.registerTokenForAPNS.
    If you use our KnockAppDelegate, the token registration will be handled for you automatically.
    */
    func apnsDeviceToken() async -> String? {
        await environment.getDeviceToken()
    }
}
