//
//  KnockMessageStatus.swift
//
//
//  Created by Matt Gardner on 1/19/24.
//

import Foundation

public extension Knock {
    enum KnockMessageStatus: String, Codable {
        // validate the possible values, from: https://docs.knock.app/reference#messages
        case queued
        case sent
        case delivered
        case delivery_attempted
        case undelivered
        case seen
        case unseen
    }
    
    enum KnockMessageEngagementStatus: String, Codable {
        // validate the possible values, from: https://docs.knock.app/reference#messages
        case seen
        case read
        case interacted
        case link_clicked
        case archived
    }
    
    enum KnockMessageStatusUpdateType: String {
        case seen
        case read
        case interacted
        case archive
    }
    
    enum KnockMessageStatusBatchUpdateType: String, Codable {
        case seen
        case read
        case interacted
        case archived
        case unseen
        case unread
        case unarchived
    }
}
