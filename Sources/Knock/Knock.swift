//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import SwiftUI
import AnyCodable

public class Knock {
    public let publishableKey: String
    public let userId: String
    public let userToken: String?
    
    internal let api: KnockAPI
    
    public var feedManager: FeedManager?
    
//    @Published public var feedItems = [FeedItem]()
//    @Published public var totalCount = 0
//    @Published public var unreadCount = 0
//    @Published public var unseenCount = 0
    
    public enum KnockError: Error {
        case runtimeError(String)
    }
    
    // MARK: Constructor
    
    /**
     Returns a new instance of the Knock Client
     
     - Parameters:
        - publishableKey: your public API key
        - userId: the user-id that will be used in the subsequent method calls
        - userToken: [optional] user token. Used in production when enhanced security is enabled
        - hostname: [optional] custom hostname of the API, including schema (https://)
     */
    public init(publishableKey: String, userId: String, userToken: String? = nil, hostname: String? = nil) throws {
        guard publishableKey.hasPrefix("sk_") == false else { throw KnockError.runtimeError("[Knock] You are using your secret API key on the client. Please use the public key.") }
        
        self.publishableKey = publishableKey
        self.userId = userId
        self.userToken = userToken
        
        self.api = KnockAPI(publishableKey: publishableKey, userToken: userToken, hostname: hostname)
    }
}
