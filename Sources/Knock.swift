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
    internal static let loggingSubsytem = "knock-swift"
        
    public var feedManager: FeedManager?
    
    internal lazy var userModule = UserModule()
    internal lazy var preferenceModule = PreferenceModule()
    internal lazy var messageModule = MessageModule()
    internal lazy var channelModule = ChannelModule()
    
    /**
     Returns a new instance of the Knock Client

     - Parameters:
        - publishableKey: your public API key
        - options: [optional] Options for customizing the Knock instance.
     */
    public init(publishableKey: String, hostname: String? = nil) throws {
        try KnockEnvironment.shared.setPublishableKey(key: publishableKey)
        KnockEnvironment.shared.setBaseUrl(baseUrl: hostname)
    }
    
    @available(*, deprecated, message: "See v1.0.0 migration guide for more details.")
    public init(publishableKey: String, userId: String, userToken: String? = nil, hostname: String? = nil) throws {
        try KnockEnvironment.shared.setPublishableKey(key: publishableKey)
        KnockEnvironment.shared.setUserInfo(userId: userId, userToken: userToken)
        KnockEnvironment.shared.setBaseUrl(baseUrl: hostname)
    }
    
    internal func resetInstance() {
        self.feedManager = nil
        KnockEnvironment.shared.resetEnvironment()
    }
}

public extension Knock {
   var userId: String? {
       get {
           return KnockEnvironment.shared.userId
       }
   }
}



// TODO: Possibly return user in authenticate method.
// TODO: Ensure threads are correct
// TODO: Handle AppDelegate
// TODO: Evaluate classes and determine if they should be structs
