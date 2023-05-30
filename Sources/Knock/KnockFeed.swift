//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation
import SwiftPhoenixClient
import AnyCodable

public extension Knock {
    struct Block: Codable {
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

    struct NotificationSource: Codable {
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

    struct FeedItem: Codable {
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

    struct PageInfo: Codable {
        public var before: String?
        public var after: String?
        public var page_size: Int = 0
    }

    struct FeedMetadata: Codable {
        public var total_count: Int = 0
        public var unread_count: Int = 0
        public var unseen_count: Int = 0
    }

    struct Feed: Codable {
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
    
    enum BulkOperationStatus: String, Codable {
        case queued
        case processing
        case completed
        case failed
    }
    
    struct BulkOperation: Codable {
        public let id: String
        public let name: String
        public let status: BulkOperationStatus
        public let estimated_total_rows: Int
        public let processed_rows: Int
        public let started_at: Date?
        public let completed_at: Date?
        public let failed_at: Date?
    }
    
    class FeedManager {
        private let api: KnockAPI
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
            // use regex and circumflex accent to mark only the starting http to be replaced and not any others
            let websocketHostname = client.api.hostname.replacingOccurrences(of: "^http", with: "ws", options: .regularExpression) // default: wss://api.knock.app
            let websocketPath = "\(websocketHostname)/ws/v1/websocket" // default: wss://api.knock.app/ws/v1/websocket
            
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
}
