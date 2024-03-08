//
//  KnockMessage.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    // https://docs.knock.app/reference#messages#feeds
    
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
        public let inserted_at: Date?
        public let updated_at: Date?
        public let source: WorkflowSource
        public let data: [String: AnyCodable]? // GenericData
    }
    
    struct WorkflowSource: Codable {
        public let key: String
        public let version_id: String
    }
    
    struct RecipientIdentifier: Codable {
        public let id: String
        public let collection: String
    }
}
