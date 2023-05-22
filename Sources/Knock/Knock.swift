//
//  Knock.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import SwiftUI
import SwiftPhoenixClient
import AnyCodable

public enum Either<T, U> {
    case left(T)
    case right(U)
}

extension Either: Decodable where T: Decodable, U: Decodable {
    public init(from decoder: Decoder) throws {
        if let value = try? T(from: decoder) {
            self = .left(value)
        }
        else if let value = try? U(from: decoder) {
            self = .right(value)
        }
        else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode \(T.self) or \(U.self)")
            throw DecodingError.dataCorrupted(context)
        }
    }
}

extension Either: Encodable where T: Encodable, U: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let value):
            try container.encode(value)
        case .right(let value):
            try container.encode(value)
        }
    }
}


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

    public struct Block: Codable {
        public let content: String
        public let name: String
        public let rendered: String
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.Block.CodingKeys> = try decoder.container(keyedBy: Knock.Block.CodingKeys.self)
            self.content = try container.decode(String.self, forKey: Knock.Block.CodingKeys.content)
            self.name = try container.decode(String.self, forKey: Knock.Block.CodingKeys.name)
            self.rendered = try container.decode(String.self, forKey: Knock.Block.CodingKeys.rendered)
        }
        
        public init(content: String, name: String, rendered: String) {
            self.content = content
            self.name = name
            self.rendered = rendered
        }
    }

    public struct NotificationSource: Codable {
        public let key: String
        public let version_id: String
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.NotificationSource.CodingKeys> = try decoder.container(keyedBy: Knock.NotificationSource.CodingKeys.self)
            self.key = try container.decode(String.self, forKey: Knock.NotificationSource.CodingKeys.key)
            self.version_id = try container.decode(String.self, forKey: Knock.NotificationSource.CodingKeys.version_id)
        }
        
        public init(key: String, version_id: String) {
            self.key = key
            self.version_id = version_id
        }
    }

    public struct FeedItem: Codable {
        public let __cursor: String
//        public let clicked_at: Date?
        public let blocks: [Block]
        public let data: [String: AnyCodable]? // GenericData
        public let id: String
        public let inserted_at: Date?
//        public let interacted_at: Date?
//        public let link_clicked_at: Date?
        public var read_at: Date?
        public var seen_at: Date?
        public let tenant: String
        public let total_activities: Int
        public let total_actors: Int
        public let updated_at: Date?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.FeedItem.CodingKeys> = try decoder.container(keyedBy: Knock.FeedItem.CodingKeys.self)
            self.__cursor = try container.decode(String.self, forKey: Knock.FeedItem.CodingKeys.__cursor)
            self.blocks = try container.decode([Knock.Block].self, forKey: Knock.FeedItem.CodingKeys.blocks)
            self.data = try container.decodeIfPresent([String : AnyCodable].self, forKey: Knock.FeedItem.CodingKeys.data)
            self.id = try container.decode(String.self, forKey: Knock.FeedItem.CodingKeys.id)
            self.inserted_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.inserted_at)
            self.read_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.read_at)
            self.seen_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.seen_at)
            self.tenant = try container.decode(String.self, forKey: Knock.FeedItem.CodingKeys.tenant)
            self.total_activities = try container.decode(Int.self, forKey: Knock.FeedItem.CodingKeys.total_activities)
            self.total_actors = try container.decode(Int.self, forKey: Knock.FeedItem.CodingKeys.total_actors)
            self.updated_at = try container.decodeIfPresent(Date.self, forKey: Knock.FeedItem.CodingKeys.updated_at)
        }
        
        public init(__cursor: String, blocks: [Block], data: [String : AnyCodable]?, id: String, inserted_at: Date?, read_at: Date? = nil, seen_at: Date? = nil, tenant: String, total_activities: Int, total_actors: Int, updated_at: Date?) {
            self.__cursor = __cursor
            self.blocks = blocks
            self.data = data
            self.id = id
            self.inserted_at = inserted_at
            self.read_at = read_at
            self.seen_at = seen_at
            self.tenant = tenant
            self.total_activities = total_activities
            self.total_actors = total_actors
            self.updated_at = updated_at
        }
    }

    public struct PageInfo: Codable {
        public var before: String?
        public var after: String?
        public var page_size: Int = 0
    }

    public struct FeedMetadata: Codable {
        public var total_count: Int = 0
        public var unread_count: Int = 0
        public var unseen_count: Int = 0
    }

    public struct Feed: Codable {
        public var entries: [FeedItem] = []
        public var meta: FeedMetadata = FeedMetadata()
        public var page_info: PageInfo = PageInfo()
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.Feed.CodingKeys> = try decoder.container(keyedBy: Knock.Feed.CodingKeys.self)
            self.entries = try container.decode([Knock.FeedItem].self, forKey: Knock.Feed.CodingKeys.entries)
            self.meta = try container.decode(Knock.FeedMetadata.self, forKey: Knock.Feed.CodingKeys.meta)
            self.page_info = try container.decode(Knock.PageInfo.self, forKey: Knock.Feed.CodingKeys.page_info)
        }
        
        public init(entries: [FeedItem], meta: FeedMetadata, page_info: PageInfo) {
            self.entries = entries
            self.meta = meta
            self.page_info = page_info
        }
        
        public init() {}
    }
    
    public enum BulkOperationStatus: String, Codable {
        case queued
        case processing
        case completed
        case failed
    }
    
    public struct BulkOperation: Codable {
        public let id: String
        public let name: String
        public let status: BulkOperationStatus
        public let estimated_total_rows: Int
        public let processed_rows: Int
        public let started_at: Date?
        public let completed_at: Date?
        public let failed_at: Date?
    }
    
    public class FeedManager {
        private let api: KnockAPI
        private let websocketPath = "wss://api.knock.app/ws/v1/websocket"
        private let socket: Socket
        private var feedChannel: Channel?
        private let userId: String
        private let feedId: String
        private var feedTopic: String
        
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
        }
        
        public enum BulkChannelMessageStatusUpdateType: String {
            case seen
            case read
            case archived
            case unseen
            case unread
            case unarchived
        }
        
        public init(client: Knock, feedId: String) {
            self.socket = Socket(websocketPath, params: ["vsn": "2.0.0", "api_key": client.publishableKey, "user_token": client.userToken ?? ""])
            self.userId = client.userId
            self.feedId = feedId
            self.feedTopic = "feeds:\(feedId):\(client.userId)"
            self.api = client.api
        }
        
        public func connectToFeed() {
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
            
            // Setup the Channel to receive and send messages
            let channel = socket.channel(feedTopic, params: [:])
            
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
        
        public func getUserFeedContent(options: FeedClientOptions, completionHandler: @escaping ((Result<Feed, Error>) -> Void)) {
            let triggerDataJSON = Knock.encodeGenericDataToJSON(data: options.trigger_data)
            
            let queryItems = [
                URLQueryItem(name: "page_size", value: (options.page_size != nil) ? "\(options.page_size!)" : nil),
                URLQueryItem(name: "after", value: options.after),
                URLQueryItem(name: "before", value: options.before),
                URLQueryItem(name: "source", value: options.source),
                URLQueryItem(name: "tenant", value: options.tenant),
                URLQueryItem(name: "has_tenant", value: (options.has_tenant != nil) ? "true" : "false"),
                URLQueryItem(name: "status", value: (options.status != nil) ? options.status?.rawValue : ""),
                URLQueryItem(name: "archived", value: (options.archived != nil) ? options.archived?.rawValue : ""),
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
    }
    
    // MARK: Channels
    
    public struct ChannelData: Codable {
        public let channel_id: String
        public let data: [String: AnyCodable]? // GenericData
    }
    
    public func getUserChannelData(channelId: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        self.api.decodeFromGet(ChannelData.self, path: "/users/\(userId)/channel_data/\(channelId)", queryItems: nil, then: completionHandler)
    }
    
    /**
     Sets channel data for the user and the channel specified.
     
     - Parameters:
        - userId: the id of the user
        - channelId: the id of the channel
        - data: the shape of the payload varies depending on the channel. You can learn more about channel data schemas [here](https://docs.knock.app/send-notifications/setting-channel-data#provider-data-requirements).
     */
    public func updateUserChannelData(channelId: String, data: AnyEncodable, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        let payload = [
            "data": data
        ]
        self.api.decodeFromPut(ChannelData.self, path: "/users/\(userId)/channel_data/\(channelId)", body: payload, then: completionHandler)
    }
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - userId: the id of the user
        - channelId: the id of the APNS channel
        - token: the APNS device token as `Data`
     */
    public func registerTokenForAPNS(channelId: String, token: Data, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        // 1. Convert device token to string
        let tokenParts = token.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let tokenString = tokenParts.joined()
        
        registerTokenForAPNS(channelId: channelId, token: tokenString, completionHandler: completionHandler)
    }
    
    /**
     Registers an Apple Push Notification Service token so that the device can receive remote push notifications. This is a convenience method that internally gets the channel data and searches for the token. If it exists, then it's already registered and it returns. If the data does not exists or the token is missing from the array, it's added.
     
     You can learn more about APNS [here](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).
     
     - Attention: There's a race condition because the getting/setting of the token are not made in a transaction.
     
     - Parameters:
        - userId: the id of the user
        - channelId: the id of the APNS channel
        - token: the APNS device token as a `String`
     */
    public func registerTokenForAPNS(channelId: String, token: String, completionHandler: @escaping ((Result<ChannelData, Error>) -> Void)) {
        getUserChannelData(channelId: channelId) { result in
            switch result {
            case .failure(_):
                // there's no data registered on that channel for that user, we'll create a new record
                print("there's no data registered on that channel for that user, we'll create a new record")
                let data: AnyEncodable = [
                    "tokens": [token]
                ]
                self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
            case .success(let channelData):
                guard let data = channelData.data else {
                    // we don't have data for that channel for that user, we'll create a new record
                    print("we don't have data for that channel for that user, we'll create a new record")
                    let data: AnyEncodable = [
                        "tokens": [token]
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                    return
                }
                
                guard var tokens = data["tokens"]?.value as? [String] else {
                    // we don't have an array of valid tokens so we'll register a new one
                    print("we don't have an array of valid tokens so we'll register a new one")
                    let data: AnyEncodable = [
                        "tokens": [token]
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                    return
                }
                
                if tokens.contains(token) {
                    // we already have the token registered
                    print("we already have the token registered")
                    completionHandler(.success(channelData))
                }
                else {
                    // we need to register the token
                    print("we need to register the token")
                    tokens.append(token)
                    let data: AnyEncodable = [
                        "tokens": tokens
                    ]
                    self.updateUserChannelData(channelId: channelId, data: data, completionHandler: completionHandler)
                }
            }
        }
    }
    
    // MARK: Messages
    
    public enum KnockMessageStatus: String, Codable {
        // validate the possible values, from: https://docs.knock.app/reference#messages
        
        case queued
        case sent
        case delivered
        case delivery_attempted
        case undelivered
        case seen
//        case read
//        case interacted
//        case archived
        case unseen
//        case unread
//        case unarchived
    }
    
    public enum KnockMessageEngagementStatus: String, Codable {
        // validate the possible values, from: https://docs.knock.app/reference#messages
        
        case seen
        case read
        case interacted
        case link_clicked
        case archived
    }
    
    public struct WorkflowSource: Codable {
        public let key: String
        public let version_id: String
    }
    
    public struct RecipientIdentifier: Codable {
        public let id: String
        public let collection: String
    }
    
    // Named `KnockMessage` and not only `Message` to avoid a name colission to the type in `SwiftPhoenixClient`
    public struct KnockMessage: Codable {
        public let id: String
        public let channel_id: String
        // check how to handle the next attribute, https://docs.knock.app/reference#messages
        // string or RecipientIdentifier
        // The ID of the user who received the message. If the recipient is an object, the result will be an object containing its id and collection
        public let recipient: Either<String, RecipientIdentifier>
        
        // the next computed property simplifies the process of accessing the `recipient-id` from the Either type above
        public var recipientId: String {
            get {
                switch recipient {
                case .left(let value):
                    return value
                case .right(let value):
                    return value.id
                }
            }
        }
        public let workflow: String
        public let tenant: String? // the documentation (https://docs.knock.app/reference#messages) says that it's not optional but it can be, so it's declared optional here. CHECK THIS on the docs
        public let status: KnockMessageStatus
        public let engagement_statuses: [KnockMessageEngagementStatus]
        public let seen_at: Date?
        public let read_at: Date?
        public let interacted_at: Date?
        public let link_clicked_at: Date?
        public let archived_at: Date?
//        public let inserted_at: Date? // check datetime format, it differs from the others
//        public let updated_at: Date? // check datetime format, it differs from the others
        public let source: WorkflowSource
        public let data: [String: AnyCodable]? // GenericData
    }
    
    public enum KnockMessageStatusUpdateType: String {
        case seen
        case read
        case interacted
        case archive
    }
    
    public enum KnockMessageStatusBulkUpdateType: String, Codable {
        case seen
        case read
        case interacted
        case archived
        case unseen
        case unread
        case unarchived
    }
    
    public func getMessage(messageId: String, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromGet(KnockMessage.self, path: "/messages/\(messageId)", queryItems: nil, then: completionHandler)
    }
    
    public func updateMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        updateMessageStatus(messageId: message.id, status: status, completionHandler: completionHandler)
    }
    
    public func updateMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromPut(KnockMessage.self, path: "/messages/\(messageId)/\(status.rawValue)", body: nil, then: completionHandler)
    }
    
    public func deleteMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        deleteMessageStatus(messageId: message.id, status: status, completionHandler: completionHandler)
    }
    
    public func deleteMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromDelete(KnockMessage.self, path: "/messages/\(messageId)/\(status.rawValue)", body: nil, then: completionHandler)
    }
    
    /**
     Make a status update for a message
     
     - Parameters:
        - item: the `KnockMessage` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    public func bulkUpdateMessageStatus(message: KnockMessage, status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        makeStatusUpdate(messages: [message], status: status, completionHandler: completionHandler)
    }
    
    /**
     Make a status update for a message
     
     - Parameters:
        - item: the `FeedItem` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    public func bulkUpdateMessageStatus(messageId: String, status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        makeStatusUpdate(messageIds: [messageId], status: status, completionHandler: completionHandler)
    }
    
    /**
     Make a status update for a list of messages
     
     - Parameters:
        - items: the list of `FeedItem` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    public func makeStatusUpdate(messageIds: [String], status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
    
    /**
     Make a status update for a list of messages
     
     - Parameters:
        - items: the list of `FeedItem` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    public func makeStatusUpdate(messages: [KnockMessage], status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let messageIds = messages.map{$0.id}
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
    
    // MARK: Preferences
    
    /**
     This struct is here to improve the ease of use in SwiftUI or UIKit. It's intented to be created from a `ChannelTypePreferences` struct using the method `asArray()` that returns an array of `ChannelTypePreferenceItem` that contains only the preferences that are not nil.
     
     It conforms to `Equatable` to be able to be monitored with `onChange` inside a SwiftUI List
     */
    public struct ChannelTypePreferenceItem: Identifiable, Equatable {
        public var id: ChannelTypeKey
        public var value: Bool
        
        public init(id: ChannelTypeKey, value: Bool) {
            self.id = id
            self.value = value
        }
    }
    
    /**
     This struct will be converted to a dictionary when it's encoded to be sent to the API and it will only include the keys that are not set to nil
     When decoding from the API, if the key does not exists, the corresponding attribute will be nil here on the struct
     
     TODO: Just like the JS client, it would be great to pull this in (the keys/attributes) from an external location; it may be a bit tricky since Swift wants concrete types, but it may be a fun experiment to try to solve this.
     */
    public struct ChannelTypePreferences: Codable {
        public var email: Bool?
        public var in_app_feed: Bool?
        public var sms: Bool?
        public var push: Bool?
        public var chat: Bool?
        
        public func asArray() -> [ChannelTypePreferenceItem] {
            var array = [ChannelTypePreferenceItem]()
            
            if let bool = email {
                array.append(Knock.ChannelTypePreferenceItem(id: .email, value: bool))
            }
            
            if let bool = in_app_feed {
                array.append(Knock.ChannelTypePreferenceItem(id: .in_app_feed, value: bool))
            }
            
            if let bool = sms {
                array.append(Knock.ChannelTypePreferenceItem(id: .sms, value: bool))
            }
            
            if let bool = push {
                array.append(Knock.ChannelTypePreferenceItem(id: .push, value: bool))
            }
            
            if let bool = chat {
                array.append(Knock.ChannelTypePreferenceItem(id: .chat, value: bool))
            }
            
            return array
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.ChannelTypePreferences.CodingKeys> = try decoder.container(keyedBy: Knock.ChannelTypePreferences.CodingKeys.self)
            self.email = try container.decodeIfPresent(Bool.self, forKey: Knock.ChannelTypePreferences.CodingKeys.email)
            self.in_app_feed = try container.decodeIfPresent(Bool.self, forKey: Knock.ChannelTypePreferences.CodingKeys.in_app_feed)
            self.sms = try container.decodeIfPresent(Bool.self, forKey: Knock.ChannelTypePreferences.CodingKeys.sms)
            self.push = try container.decodeIfPresent(Bool.self, forKey: Knock.ChannelTypePreferences.CodingKeys.push)
            self.chat = try container.decodeIfPresent(Bool.self, forKey: Knock.ChannelTypePreferences.CodingKeys.chat)
        }
        
        public init () {}
    }
    
    public enum ChannelTypeKey: String, CaseIterable, Codable {
        case email
        case in_app_feed
        case sms
        case push
        case chat
    }
    
    public struct Condition: Codable {
        public let variable: String
        public let `operator`: String // TODO: check this case. `operator` is a reserved word in Swift. Maybe handle it on the encoder or use backticks here
        public let argument: String
    }
    
    public struct WorkflowPreference: Codable {
        public let channel_types: ChannelTypePreferences
    }

    public struct PreferenceSet: Codable {
        public var id: String? = nil // default or tenant.id; TODO: check this, because the API allows any value to be used here, not only default and an existing tenant.id
        public var channel_types: ChannelTypePreferences? = ChannelTypePreferences()
        public var workflows: [String: Either<Bool, WorkflowPreference>]?
        public var categories: [String: Either<Bool, WorkflowPreference>]?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.PreferenceSet.CodingKeys> = try decoder.container(keyedBy: Knock.PreferenceSet.CodingKeys.self)
            self.id = try container.decodeIfPresent(String.self, forKey: Knock.PreferenceSet.CodingKeys.id)
            self.channel_types = try container.decodeIfPresent(Knock.ChannelTypePreferences.self, forKey: Knock.PreferenceSet.CodingKeys.channel_types)
            self.workflows = try container.decodeIfPresent([String : Either<Bool, Knock.WorkflowPreference>].self, forKey: Knock.PreferenceSet.CodingKeys.workflows)
            self.categories = try container.decodeIfPresent([String : Either<Bool, Knock.WorkflowPreference>].self, forKey: Knock.PreferenceSet.CodingKeys.categories)
        }
        
        public init() {}
    }
    
    public struct WorkflowPreferenceBoolItem: Identifiable, Equatable {
        public var id: String
        public var value: Bool
        
        public init(id: String, value: Bool) {
            self.id = id
            self.value = value
        }
    }
    
    public struct WorkflowPreferenceChannelTypesItem: Identifiable, Equatable {
        public var id: String // workflow or category id
        public var channelTypes: [ChannelTypePreferenceItem]
        
        public init(id: String, channelTypes: [ChannelTypePreferenceItem]) {
            self.id = id
            self.channelTypes = channelTypes
        }
    }
    
    public struct WorkflowPreferenceItems: Identifiable {
        public var id = UUID.init().uuidString
        public var boolValues: [WorkflowPreferenceBoolItem] = []
        public var channelTypeValues: [WorkflowPreferenceChannelTypesItem] = []
        
        public func toPreferenceDictionary() -> [String: Either<Bool, Knock.WorkflowPreference>] {
            var result = [String: Either<Bool, Knock.WorkflowPreference>]()
            
            boolValues.forEach { boolItem in
                result[boolItem.id] = .left(boolItem.value)
            }
            
            channelTypeValues.forEach { channelsItem in
                let workflowPreference = WorkflowPreference(channel_types: channelsItem.channelTypes.toChannelTypePreferences())
                result[channelsItem.id] = .right(workflowPreference)
            }
            
            return result
        }
        
        public init(id: String = UUID.init().uuidString, boolValues: [WorkflowPreferenceBoolItem], channelTypeValues: [WorkflowPreferenceChannelTypesItem]) {
            self.id = id
            self.boolValues = boolValues
            self.channelTypeValues = channelTypeValues
        }
        
        public init() {}
    }
    
    public func getAllUserPreferences(completionHandler: @escaping ((Result<[PreferenceSet], Error>) -> Void)) {
        self.api.decodeFromGet([PreferenceSet].self, path: "/users/\(userId)/preferences", queryItems: nil, then: completionHandler)
    }
    
    public func getUserPreferences(preferenceId: String, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        self.api.decodeFromGet(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", queryItems: nil, then: completionHandler)
    }
    
    public func setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet, completionHandler: @escaping ((Result<PreferenceSet, Error>) -> Void)) {
        let payload = preferenceSet
        self.api.decodeFromPut(PreferenceSet.self, path: "/users/\(userId)/preferences/\(preferenceId)", body: payload, then: completionHandler)
    }
    
    // MARK: Users
    
    public struct User: Codable {
        public let id: String
        public let name: String?
        public let email: String?
        public let avatar: String?
        public let phone_number: String?
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Knock.User.CodingKeys> = try decoder.container(keyedBy: Knock.User.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: Knock.User.CodingKeys.id)
            self.name = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.name)
            self.email = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.email)
            self.avatar = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.avatar)
            self.phone_number = try container.decodeIfPresent(String.self, forKey: Knock.User.CodingKeys.phone_number)
        }
        
        public init(id: String, name: String?, email: String?, avatar: String?, phone_number: String?) {
            self.id = id
            self.name = name
            self.email = email
            self.avatar = avatar
            self.phone_number = phone_number
        }
    }
    
    public func getUser(userId: String, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromGet(User.self, path: "/users/\(userId)", queryItems: nil, then: completionHandler)
    }
    
    public func updateUser(user: User, completionHandler: @escaping ((Result<User, Error>) -> Void)) {
        self.api.decodeFromPut(User.self, path: "/users/\(userId)/\(user.id)", body: user, then: completionHandler)
    }
    
    // MARK: Utilities
    
    private static func encodeGenericDataToJSON(data: [String: AnyCodable]?) -> String? {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        var jsonString: String?
        
        if let triggerData = try? encoder.encode(data) {
            jsonString = String(data: triggerData, encoding: .utf8)
        }
        
        return jsonString
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

public extension Encodable {
    /**
     This will allow types like `ChannelTypePreferences` to be transformed to a Dictionary to be encoded and sent to the API and only include non-nil attributes
     */
    func dictionary() -> [String:Any] {
        var dict = [String:Any]()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard let key = child.label else { continue }
            let childMirror = Mirror(reflecting: child.value)
            
            switch childMirror.displayStyle {
            case .struct, .class:
                let childDict = (child.value as! Encodable).dictionary()
                dict[key] = childDict
            case .collection:
                let childArray = (child.value as! [Encodable]).map({ $0.dictionary() })
                dict[key] = childArray
            case .set:
                let childArray = (child.value as! Set<AnyHashable>).map({ ($0 as! Encodable).dictionary() })
                dict[key] = childArray
            case .optional:
                if childMirror.children.count == 0 {
                    dict[key] = nil
                } else {
                    let (_, value) = childMirror.children.first!
                    
                    switch value {
                    case let value as Bool:
                        dict[key] = value
                    case let value as Int:
                        dict[key] = value
                    case let value as Int8:
                        dict[key] = value
                    case let value as Int16:
                        dict[key] = value
                    case let value as Int32:
                        dict[key] = value
                    case let value as Int64:
                        dict[key] = value
                    case let value as UInt:
                        dict[key] = value
                    case let value as UInt8:
                        dict[key] = value
                    case let value as UInt16:
                        dict[key] = value
                    case let value as UInt32:
                        dict[key] = value
                    case let value as UInt64:
                        dict[key] = value
                    case let value as Float:
                        dict[key] = value
                    case let value as Double:
                        dict[key] = value
                    case let value as String:
                        dict[key] = value
                    default:
                        dict[key] = nil
                    }
                }
            default:
                dict[key] = child.value
            }
        }
        
        return dict
    }
}

public extension [String: Either<Bool, Knock.WorkflowPreference>] {
    func toArrays() -> Knock.WorkflowPreferenceItems {
        var result = Knock.WorkflowPreferenceItems()
        
        self.sorted(by: { lhs, rhs in
            return lhs.key < rhs.key
        }).forEach { key, value in
            switch value {
            case .left(let value):
                let newItem = Knock.WorkflowPreferenceBoolItem(id: key, value: value)
                result.boolValues.append(newItem)
            case .right(let value):
                let channelPrefs = value.channel_types.asArray()
                let newItem = Knock.WorkflowPreferenceChannelTypesItem(id: key, channelTypes: channelPrefs)
                result.channelTypeValues.append(newItem)
            }
        }
        
        return result
    }
}

public extension Array<Knock.ChannelTypePreferenceItem> {
    func toChannelTypePreferences() -> Knock.ChannelTypePreferences {
        var result = Knock.ChannelTypePreferences()

        self.forEach{ item in
            switch item.id {
            case .email:
                result.email = item.value
            case .in_app_feed:
                result.in_app_feed = item.value
            case .sms:
                result.sms = item.value
            case .push:
                result.push = item.value
            case .chat:
                result.chat = item.value
            }
        }

        return result
    }
}
