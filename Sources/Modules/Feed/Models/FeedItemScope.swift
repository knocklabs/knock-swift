//
//  FeedItemScope.swift
//
//
//  Created by Matt Gardner on 1/23/24.
//

import Foundation


extension Knock {
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
    
    public enum BulkChannelMessageStatusUpdateType: String {
        case seen
        case read
        case archived
        case unseen
        case unread
        case unarchived
    }
}
