//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import SwiftUI

// Knock client SDK.
public class Knock {
    internal static let clientVersion = "1.0.0"
    internal static let loggingSubsytem = "knock-swift"
    
    internal var api: KnockAPI
    
    public var feedManager: FeedManager?
    public internal(set) var userId: String?
    public internal(set) var pushChannelId: String?
    public internal(set) var userDeviceToken: String?

    /**
     Returns a new instance of the Knock Client

     - Parameters:
        - publishableKey: your public API key
        - userId: the user-id that will be used in the subsequent method calls
        - userToken: [optional] user token. Used in production when enhanced security is enabled
        - options: [optional] Options for customizing the Knock instance.
     */
    public init(publishableKey: String, options: KnockOptions?) {
        self.api = KnockAPI(publishableKey: publishableKey, hostname: options?.host)
    }
    
    internal func resetInstance() {
        self.userId = nil
        self.feedManager = nil
        self.userDeviceToken = nil
        self.pushChannelId = nil
        self.api.updateUserInfo(userToken: nil)
    }
    
    internal var safeUserId: String {
        guard let id = userId else {
            fatalError("[Knock] You must call Knock.shared.authenticate() first before trying to make a request where userId is required...")
        }
        return id
    }
}

extension Knock {
    // Configuration options for the Knock client SDK.
    public struct KnockOptions {
        var host: String?
    }
    
    public enum KnockError: Error {
        case runtimeError(String)
    }
}


// NoTES:
// Should we provide more safety around userID being invalid? Instead of fatal erroring out the app.
// Ensure that switching api to struct is the right move.
