//
//  FeedManager.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation
import SwiftPhoenixClient

public extension Knock {
    
    class FeedManager {
        private let api: KnockAPI
        private let socket: Socket
        private var feedChannel: Channel?
        private let userId: String
        private let feedId: String
        private var feedTopic: String
        private var defaultFeedOptions: FeedClientOptions
        
        public enum FeedItemScope: String, Codable {
            // TODO: check engagement_status in https://docs.knock.app/reference#bulk-update-channel-message-status
            // extras:
            // case archived
            // case unarchived
            // case interacted
            // minus "all"
            case all
            case unread
            case read
            case unseen
            case seen
        }
        
        public enum FeedItemArchivedScope: String, Codable {
            case include
            case exclude
            case only
        }
        
        public struct FeedClientOptions: Codable {
            public var before: String?
            public var after: String?
            public var page_size: Int?
            public var status: FeedItemScope?
            public var source: String? // Optionally scope all notifications to a particular source only
            public var tenant: String?  // Optionally scope all requests to a particular tenant
            public var has_tenant: Bool? // Optionally scope to notifications with any tenancy or no tenancy
            public var archived: FeedItemArchivedScope? // Optionally scope to a given archived status (defaults to `exclude`)
            public var trigger_data: [String: AnyCodable]? // GenericData
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<Knock.FeedManager.FeedClientOptions.CodingKeys> = try decoder.container(keyedBy: Knock.FeedManager.FeedClientOptions.CodingKeys.self)
                self.before = try container.decodeIfPresent(String.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.before)
                self.after = try container.decodeIfPresent(String.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.after)
                self.page_size = try container.decodeIfPresent(Int.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.page_size)
                self.status = try container.decodeIfPresent(Knock.FeedManager.FeedItemScope.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.status)
                self.source = try container.decodeIfPresent(String.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.source)
                self.tenant = try container.decodeIfPresent(String.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.tenant)
                self.has_tenant = try container.decodeIfPresent(Bool.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.has_tenant)
                self.archived = try container.decodeIfPresent(Knock.FeedManager.FeedItemArchivedScope.self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.archived)
                self.trigger_data = try container.decodeIfPresent([String : AnyCodable].self, forKey: Knock.FeedManager.FeedClientOptions.CodingKeys.trigger_data)
            }
            
            public init(before: String? = nil, after: String? = nil, page_size: Int? = nil, status: FeedItemScope? = nil, source: String? = nil, tenant: String? = nil, has_tenant: Bool? = nil, archived: FeedItemArchivedScope? = nil, trigger_data: [String : AnyCodable]? = nil) {
                self.before = before
                self.after = after
                self.page_size = page_size
                self.status = status
                self.source = source
                self.tenant = tenant
                self.has_tenant = has_tenant
                self.archived = archived
                self.trigger_data = trigger_data
            }
            
            /**
             Returns a new struct of type `FeedClientOptions` with the options passed as the parameter merged into it.
             
             - Parameters:
                - options: the options to merge with the current struct, if they are nil, only a copy of `self` will be returned
             */
            public func mergeOptions(options: FeedClientOptions? = nil) -> FeedClientOptions {
                // initialize a new `mergedOptions` struct with all the properties of the `self` struct
                var mergedOptions = FeedClientOptions(
                    before: self.before,
                    after: self.after,
                    page_size: self.page_size,
                    status: self.status,
                    source: self.source,
                    tenant: self.tenant,
                    has_tenant: self.has_tenant,
                    archived: self.archived,
                    trigger_data: self.trigger_data
                )
                
                // check if the passed options are not nil
                guard let options = options else {
                    return mergedOptions
                }
                
                // for each one of the properties `not nil` in the parameter `options`, override the ones in the new struct
                if options.before != nil {
                    mergedOptions.before = options.before
                }
                if options.after != nil {
                    mergedOptions.after = options.after
                }
                if options.page_size != nil {
                    mergedOptions.page_size = options.page_size
                }
                if options.status != nil {
                    mergedOptions.status = options.status
                }
                if options.source != nil {
                    mergedOptions.source = options.source
                }
                if options.tenant != nil {
                    mergedOptions.tenant = options.tenant
                }
                if options.has_tenant != nil {
                    mergedOptions.has_tenant = options.has_tenant
                }
                if options.archived != nil {
                    mergedOptions.archived = options.archived
                }
                if options.trigger_data != nil {
                    mergedOptions.trigger_data = options.trigger_data
                }
                
                return mergedOptions
            }
        }
        
        public enum BulkChannelMessageStatusUpdateType: String {
            case seen
            case read
            case archived
            case unseen
            case unread
            case unarchived
        }
        
        public init(client: Knock, feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) {
            // use regex and circumflex accent to mark only the starting http to be replaced and not any others
            let websocketHostname = client.api.hostname.replacingOccurrences(of: "^http", with: "ws", options: .regularExpression) // default: wss://api.knock.app
            let websocketPath = "\(websocketHostname)/ws/v1/websocket" // default: wss://api.knock.app/ws/v1/websocket
            
            self.socket = Socket(websocketPath, params: ["vsn": "2.0.0", "api_key": client.publishableKey, "user_token": client.userToken ?? ""])
            self.userId = client.userId
            self.feedId = feedId
            self.feedTopic = "feeds:\(feedId):\(client.userId)"
            self.api = client.api
            self.defaultFeedOptions = options
        }
        
        /**
         Connect to the feed via socket. This will initialize the connection. You should also call the `on(eventName, completionHandler)` function to delegate what should be executed on certain received events and the `disconnectFromFeed()` function to terminate the connection.

         - Parameters:
            - options: options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
         */
        public func connectToFeed(options: FeedClientOptions? = nil) {
            // Setup the socket to receive open/close events
            socket.delegateOnOpen(to: self) { (self) in
                print("Socket Opened")
            }
            
            socket.delegateOnClose(to: self) { (self) in
                print("Socket Closed")
            }
            
            socket.delegateOnError(to: self) { (self, error) in
                let (error, response) = error
                if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode > 400 {
                    print("Socket Errored. \(statusCode)")
                    self.socket.disconnect()
                } else {
                    print("Socket Errored. \(error)")
                }
            }
            
            socket.logger = { msg in print("LOG:", msg) }
            
            let mergedOptions = defaultFeedOptions.mergeOptions(options: options)
            
            let params = paramsFromOptions(options: mergedOptions)
            
            // Setup the Channel to receive and send messages
            let channel = socket.channel(feedTopic, params: params)
            
            // Now connect the socket and join the channel
            self.feedChannel = channel
            self.feedChannel?
                .join()
                .delegateReceive("ok", to: self) { (self, _) in
                    print("CHANNEL: \(channel.topic) joined")
                }
                .delegateReceive("error", to: self) { (self, message) in
                    print("CHANNEL: \(channel.topic) failed to join. \(message.payload)")
                }
            
            self.socket.connect()
        }
        
        public func on(eventName: String, completionHandler: @escaping ((Message) -> Void)) {
            if let channel = feedChannel {
                channel.delegateOn(eventName, to: self) { (self, message) in
                    completionHandler(message)
                }
            }
            else {
                print("Feed channel is nil. You should call first connectToFeed()")
            }
        }
        
        public func disconnectFromFeed() {
            print("Disconnecting from feed")
            
            if let channel = self.feedChannel {
                channel.leave()
                self.socket.remove(channel)
            }
            
            self.socket.disconnect()
        }
        
        /**
         Gets the content of the user feed

         - Parameters:
            - options: options of type `FeedClientOptions` to merge with the default ones (set on the constructor) and scope as much as possible the results
            - completionHandler: the code to execute when the response is received
         */
        public func getUserFeedContent(options: FeedClientOptions? = nil, completionHandler: @escaping ((Result<Feed, Error>) -> Void)) {
            let mergedOptions = defaultFeedOptions.mergeOptions(options: options)
            
            let triggerDataJSON = Knock.encodeGenericDataToJSON(data: mergedOptions.trigger_data)
            
            let queryItems = [
                URLQueryItem(name: "page_size", value: (mergedOptions.page_size != nil) ? "\(mergedOptions.page_size!)" : nil),
                URLQueryItem(name: "after", value: mergedOptions.after),
                URLQueryItem(name: "before", value: mergedOptions.before),
                URLQueryItem(name: "source", value: mergedOptions.source),
                URLQueryItem(name: "tenant", value: mergedOptions.tenant),
                URLQueryItem(name: "has_tenant", value: (mergedOptions.has_tenant != nil) ? "true" : "false"),
                URLQueryItem(name: "status", value: (mergedOptions.status != nil) ? mergedOptions.status?.rawValue : ""),
                URLQueryItem(name: "archived", value: (mergedOptions.archived != nil) ? mergedOptions.archived?.rawValue : ""),
                URLQueryItem(name: "trigger_data", value: triggerDataJSON)
            ]
            
            api.decodeFromGet(Feed.self, path: "/users/\(userId)/feeds/\(feedId)", queryItems: queryItems) { (result) in
                completionHandler(result)
            }
        }
        
        /**
         Updates feed messages in bulk
         
         - Attention: The base scope for the call should take into account all of the options currently set on the feed, as well as being scoped for the current user. We do this so that we **ONLY** make changes to the messages that are currently in view on this feed, and not all messages that exist.

         - Parameters:
            - type: the kind of update
            - options: all the options currently set on the feed to scope as much as possible the bulk update
            - completionHandler: the code to execute when the response is received
         */
        public func makeBulkStatusUpdate(type: BulkChannelMessageStatusUpdateType, options: FeedClientOptions, completionHandler: @escaping ((Result<BulkOperation, Error>) -> Void)) {
            // TODO: check https://docs.knock.app/reference#bulk-update-channel-message-status
            // older_than: ISO-8601, check milliseconds
            // newer_than: ISO-8601, check milliseconds
            // delivery_status: one of `queued`, `sent`, `delivered`, `delivery_attempted`, `undelivered`, `not_sent`
            // engagement_status: one of `seen`, `unseen`, `read`, `unread`, `archived`, `unarchived`, `interacted`
            // Also check if the parameters sent here are valid
            let body: AnyEncodable = [
                "user_ids": [userId],
                "engagement_status": options.status != nil && options.status != .all ? options.status!.rawValue : "",
                "archived": options.archived ?? "",
                "has_tenant": options.has_tenant ?? "",
                "tenants": (options.tenant != nil) ? [options.tenant!] : ""
            ]
            
            api.decodeFromPost(BulkOperation.self, path: "/channels/\(feedId)/messages/bulk/\(type.rawValue)", body: body, then: completionHandler)
        }
        
        private func paramsFromOptions(options: FeedClientOptions) -> [String: Any] {
            var params: [String: Any] = [:]
            
            if let value = options.before {
                params["before"] = value
            }
            if let value = options.after {
                params["after"] = value
            }
            if let value = options.page_size {
                params["page_size"] = value
            }
            if let value = options.status {
                params["status"] = value.rawValue
            }
            if let value = options.source {
                params["source"] = value
            }
            if let value = options.tenant {
                params["tenant"] = value
            }
            if let value = options.has_tenant {
                params["has_tenant"] = value
            }
            if let value = options.archived {
                params["archived"] = value.rawValue
            }
            if let value = options.trigger_data {
                params["trigger_data"] = value.dictionary()
            }
            
            return params
        }
    }
}
