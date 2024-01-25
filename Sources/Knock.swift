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
    
    public internal(set) var feedManager: FeedManager?
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
        self.api.userToken = nil
    }
}

extension Knock {
    // Configuration options for the Knock client SDK.
    public struct KnockOptions {
        var host: String?
        
        init(host: String? = nil) {
            self.host = host
        }
    }
    
    public enum KnockError: Error {
        case runtimeError(String)
        case userIdError
    }
}

extension Knock.KnockError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let message):
            return message
        case .userIdError:
            return "UserId not found. Please authenticate your userId with Knock.authenticate()."
        }
    }
}
