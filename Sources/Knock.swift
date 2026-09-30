//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import Foundation

// Knock client SDK.
public final class Knock: Sendable {
    internal static let clientVersion = "1.2.9"

    private static let sharedInstance = LockIsolated(Knock())

    /// The shared Knock instance. Replaced by `resetInstanceCompletely()`.
    public static var shared: Knock {
        get { sharedInstance.value }
        set { sharedInstance.setValue(newValue) }
    }

    private let _feedManager = LockIsolated<FeedManager?>(nil)

    public var feedManager: FeedManager? {
        get { _feedManager.value }
        set { _feedManager.setValue(newValue) }
    }

    internal let environment = KnockEnvironment()
    internal let authenticationModule = AuthenticationModule()
    internal let userModule = UserModule()
    internal let preferenceModule = PreferenceModule()
    internal let messageModule = MessageModule()
    internal let channelModule = ChannelModule()
    internal let logger = KnockLogger()
    
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
        Knock.sharedInstance.setValue(Knock())
    }
}

public extension Knock {
    struct KnockStartupOptions: Sendable {
        public init(hostname: String? = nil, loggingOptions: LoggingOptions = .errorsOnly) {
            self.hostname = hostname
            self.loggingOptions = loggingOptions
        }
        var hostname: String?
        var loggingOptions: LoggingOptions
    }
    
    enum LoggingOptions: Sendable {
        case errorsOnly
        case errorsAndWarningsOnly
        case verbose
        case none
    }
}
