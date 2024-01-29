//
//  FeedService.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation
import SwiftPhoenixClient
import OSLog

internal class FeedModule {
    private let socket: Socket
    private var feedChannel: Channel?
    private let feedId: String
    private var feedTopic: String
    private var feedOptions: Knock.FeedClientOptions
    private let logger: Logger = Logger(subsystem: Knock.loggingSubsytem, category: "Feed")
    private let feedService = FeedService()
    
    internal init(feedId: String, options: Knock.FeedClientOptions) throws {
        // use regex and circumflex accent to mark only the starting http to be replaced and not any others
        let websocketHostname = KnockEnvironment.shared.baseUrl.replacingOccurrences(of: "^http", with: "ws", options: .regularExpression) // default: wss://api.knock.app
        let websocketPath = "\(websocketHostname)/ws/v1/websocket" // default: wss://api.knock.app/ws/v1/websocket
        let userId = try KnockEnvironment.shared.getSafeUserId()
        self.socket = Socket(websocketPath, params: ["vsn": "2.0.0", "api_key": KnockEnvironment.shared.publishableKey, "user_token": KnockEnvironment.shared.userToken ?? ""])
        self.feedId = feedId
        self.feedTopic = "feeds:\(feedId):\(userId)"
        self.feedOptions = options
    }
    
    func getUserFeedContent(options: Knock.FeedClientOptions? = nil) async throws -> Knock.Feed {
        let mergedOptions = feedOptions.mergeOptions(options: options)
        
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
        
        return try await feedService.getUserFeedContent(queryItems: queryItems, feedId: feedId)
    }
    
    func makeBulkStatusUpdate(type: Knock.BulkChannelMessageStatusUpdateType, options: Knock.FeedClientOptions) async throws -> Knock.BulkOperation {
        // TODO: check https://docs.knock.app/reference#bulk-update-channel-message-status
        // older_than: ISO-8601, check milliseconds
        // newer_than: ISO-8601, check milliseconds
        // delivery_status: one of `queued`, `sent`, `delivered`, `delivery_attempted`, `undelivered`, `not_sent`
        // engagement_status: one of `seen`, `unseen`, `read`, `unread`, `archived`, `unarchived`, `interacted`
        // Also check if the parameters sent here are valid
        let userId = try KnockEnvironment.shared.getSafeUserId()
        let body: AnyEncodable = [
            "user_ids": [userId],
            "engagement_status": options.status != nil && options.status != .all ? options.status!.rawValue : "",
            "archived": options.archived ?? "",
            "has_tenant": options.has_tenant ?? "",
            "tenants": (options.tenant != nil) ? [options.tenant!] : ""
        ]
        return try await feedService.makeBulkStatusUpdate(feedId: feedId, type: type, body: body)
    }
    
    func disconnectFromFeed() {
        logger.debug("[Knock] Disconnecting from feed")
        
        if let channel = self.feedChannel {
            channel.leave()
            self.socket.remove(channel)
        }
        
        self.socket.disconnect()
    }
    
    // Todo: Make async await method for this
    func on(eventName: String, completionHandler: @escaping ((Message) -> Void)) {
        if let channel = feedChannel {
            channel.delegateOn(eventName, to: self) { (self, message) in
                completionHandler(message)
            }
        }
        else {
            logger.error("[Knock] Feed channel is nil. You should call first connectToFeed()")
        }
    }
    
    func connectToFeed(options: Knock.FeedClientOptions? = nil) {
        // Setup the socket to receive open/close events
        socket.delegateOnOpen(to: self) { (self) in
            self.logger.debug("[Knock] Socket Opened")
        }
        
        socket.delegateOnClose(to: self) { (self) in
            self.logger.debug("[Knock] Socket Closed")
        }
        
        socket.delegateOnError(to: self) { (self, error) in
            let (error, response) = error
            if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode > 400 {
                self.logger.error("[Knock] Socket Errored. \(statusCode)")
                self.socket.disconnect()
            } else {
                self.logger.error("[Knock] Socket Errored. \(error)")
            }
        }
        
        // TODO: Determine the level of logging we want from SwiftPhoenixClient. Currently this produces a lot of noise.
//            socket.logger = { msg in print("LOG:", msg) }
        
        let mergedOptions = feedOptions.mergeOptions(options: options)
        
        let params = paramsFromOptions(options: mergedOptions)
        
        // Setup the Channel to receive and send messages
        let channel = socket.channel(feedTopic, params: params)
        
        // Now connect the socket and join the channel
        self.feedChannel = channel
        self.feedChannel?
            .join()
            .delegateReceive("ok", to: self) { (self, _) in
                self.logger.debug("[Knock] CHANNEL: \(channel.topic) joined")
            }
            .delegateReceive("error", to: self) { (self, message) in
                self.logger.debug("[Knock] CHANNEL: \(channel.topic) failed to join. \(message.payload)")
            }
        
        self.socket.connect()
    }
    
    private func paramsFromOptions(options: Knock.FeedClientOptions) -> [String: Any] {
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
