//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import SwiftUI

//public class Knock {
//    public let publishableKey: String
//    public let userId: String
//    public let userToken: String?
//    
//    internal let api: KnockAPI
//    
//    public var feedManager: FeedManager?
//    
//    public enum KnockError: Error {
//        case runtimeError(String)
//    }
//    
//    // MARK: Constructor
//    
//    /**
//     Returns a new instance of the Knock Client
//     
//     - Parameters:
//        - publishableKey: your public API key
//        - userId: the user-id that will be used in the subsequent method calls
//        - userToken: [optional] user token. Used in production when enhanced security is enabled
//        - hostname: [optional] custom hostname of the API, including schema (https://)
//     */
//    public init(publishableKey: String, userId: String, userToken: String? = nil, hostname: String? = nil) throws {
//        guard publishableKey.hasPrefix("sk_") == false else { throw KnockError.runtimeError("[Knock] You are using your secret API key on the client. Please use the public key.") }
//        
//        self.publishableKey = publishableKey
//        self.userId = userId
//        self.userToken = userToken
//        
//        self.api = KnockAPI(publishableKey: publishableKey, userToken: userToken, hostname: hostname)
//    }
//}


// Configuration options for the Knock client SDK.
public struct KnockOptions {
    var host: String?
}

// Knock client SDK.
public class Knock {
    internal static let clientVersion = "1.0.0"
    internal static let loggingSubsytem = "knock-swift"
    
    public private(set) static var shared = Knock()

    public private(set) var publishableKey: String?
//    public private(set) var userId: String?
    public internal(set) var userId: String?
    public internal(set) var userToken: String?
    public var feedManager: FeedManager?

        
    internal private(set) var api: KnockAPI!
    
    public func initialize(apiKey: String, options: KnockOptions? = nil) {
        
        // Fail loudly if we're using the wrong API key
        if apiKey.hasPrefix("sk") {
            fatalError("[Knock] You are using your secret API key on the client. Please use the public key.")
        }
        self.api = KnockAPI(apiKey: apiKey, hostname: options?.host)
    }
    
//    private func assertInitialized() {
//        if api == nil {
//            fatalError("[Knock] You must call initialize() first before trying to make a request...")
//        }
//    }
//    
//    private func assertAuthenticated() {
//        if !isAuthenticated() {
//            fatalError("[Knock] You must call authenticate() first before trying to make a request...")
//        }
//    }
//    
//    private func assertAuthAndInit() {
//        assertInitialized()
//        assertAuthenticated()
//    }
    
    internal var safePublishableKey: String {
        guard let key = publishableKey else {
            fatalError("[Knock] You must call Knock.shared.initialize() first before trying to make a request...")
        }
        return key
    }
    
    internal var safeUserId: String {
        guard let id = userId else {
            fatalError("[Knock] You must call Knock.shared.authenticate() first before trying to make a request where userId is required...")
        }
        return id
    }
}

extension Knock {
    public enum KnockError: Error {
        case runtimeError(String)
    }
}
