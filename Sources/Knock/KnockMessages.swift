//
//  File.swift
//  
//
//  Created by Diego on 30/05/23.
//

import Foundation
import AnyCodable

public extension Knock {
    // MARK: Messages
    
    enum KnockMessageStatus: String, Codable {
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
    
    enum KnockMessageEngagementStatus: String, Codable {
        // validate the possible values, from: https://docs.knock.app/reference#messages
        
        case seen
        case read
        case interacted
        case link_clicked
        case archived
    }
    
    struct WorkflowSource: Codable {
        public let key: String
        public let version_id: String
    }
    
    struct RecipientIdentifier: Codable {
        public let id: String
        public let collection: String
    }
    
    // Named `KnockMessage` and not only `Message` to avoid a name colission to the type in `SwiftPhoenixClient`
    struct KnockMessage: Codable {
        public let id: String
        public let channel_id: String
        // string or RecipientIdentifier https://docs.knock.app/reference#messages
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
    
    enum KnockMessageStatusUpdateType: String {
        case seen
        case read
        case interacted
        case archive
    }
    
    enum KnockMessageStatusBulkUpdateType: String, Codable {
        case seen
        case read
        case interacted
        case archived
        case unseen
        case unread
        case unarchived
    }
    
    func getMessage(messageId: String, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromGet(KnockMessage.self, path: "/messages/\(messageId)", queryItems: nil, then: completionHandler)
    }
    
    func updateMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        updateMessageStatus(messageId: message.id, status: status, completionHandler: completionHandler)
    }
    
    func updateMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromPut(KnockMessage.self, path: "/messages/\(messageId)/\(status.rawValue)", body: nil, then: completionHandler)
    }
    
    func deleteMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        deleteMessageStatus(messageId: message.id, status: status, completionHandler: completionHandler)
    }
    
    func deleteMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        self.api.decodeFromDelete(KnockMessage.self, path: "/messages/\(messageId)/\(status.rawValue)", body: nil, then: completionHandler)
    }
    
    /**
     Make a status update for a message
     
     - Parameters:
        - message: the `KnockMessage` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func bulkUpdateMessageStatus(message: KnockMessage, status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        makeStatusUpdate(messages: [message], status: status, completionHandler: completionHandler)
    }
    
    /**
     Make a status update for a message
     
     - Parameters:
        - messageId: the message id to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func bulkUpdateMessageStatus(messageId: String, status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        makeStatusUpdate(messageIds: [messageId], status: status, completionHandler: completionHandler)
    }
    
    /**
     Make a status update for a list of messages
     
     - Parameters:
        - messageIds: the list of message ids: `[String]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func makeStatusUpdate(messageIds: [String], status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
    
    /**
     Make a status update for a list of messages
     
     - Parameters:
        - messages: the list of messages `[KnockMessage]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func makeStatusUpdate(messages: [KnockMessage], status: KnockMessageStatusBulkUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let messageIds = messages.map{$0.id}
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
}
