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
        - publishableKey: your public API key
        - options: [optional] Options for customizing the Knock instance.
     */
    public func setup(publishableKey: String, pushChannelId: String?, options: Knock.KnockStartupOptions? = nil) throws {
        logger.loggingDebugOptions = options?.debuggingType ?? .errorsOnly
        try environment.setPublishableKey(key: publishableKey)
        environment.setBaseUrl(baseUrl: options?.hostname)
        environment.pushChannelId = pushChannelId
    }
    
    public func resetInstanceCompletely() {
        Knock.shared = Knock()
    }
}

public extension Knock {
    struct KnockStartupOptions {
        public init(hostname: String? = nil, debuggingType: DebugOptions = .errorsOnly) {
            self.hostname = hostname
            self.debuggingType = debuggingType
        }
        var hostname: String?
        var debuggingType: DebugOptions
    }
    
    enum DebugOptions {
        case errorsOnly
        case verbose
        case none
    }
}

public extension Knock {
    var userId: String? {
       get { return environment.userId }
    }
    
    var apnsDeviceToken: String? {
        get { return environment.userId }
    }
}
