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
        
        public init(feedId: String, options: FeedClientOptions = FeedClientOptions(archived: .exclude)) throws {
            guard let userId = client.userId else { throw Knock.KnockError.runtimeError("Unable to initialize FeedManager without first authenticating Knock user.") }
            // use regex and circumflex accent to mark only the starting http to be replaced and not any others
            let websocketHostname = client.api.host.replacingOccurrences(of: "^http", with: "ws", options: .regularExpression) // default: wss://api.knock.app
            let websocketPath = "\(websocketHostname)/ws/v1/websocket" // default: wss://api.knock.app/ws/v1/websocket
            
            self.socket = Socket(websocketPath, params: ["vsn": "2.0.0", "api_key": client.api.apiKey, "user_token": client.api.userToken ?? ""])
            self.userId = userId
            self.feedId = feedId
            self.feedTopic = "feeds:\(feedId):\(userId)"
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
