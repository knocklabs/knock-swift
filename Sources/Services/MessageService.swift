//
//  MessageService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

internal class MessageService: KnockAPIService {
    
    internal func getMessage(messageId: String) async throws -> Knock.KnockMessage {
        try await get(path: "/messages/\(messageId)", queryItems: nil)
    }
    
    internal func updateMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        try await put(path: "/messages/\(messageId)/\(status.rawValue)", body: nil)
    }
    
    internal func deleteMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        try await delete(path: "/messages/\(messageId)/\(status.rawValue)", body: nil)
    }
    
    internal func batchUpdateStatuses(messageIds: [String], status: Knock.KnockMessageStatusBatchUpdateType) async throws -> [Knock.KnockMessage] {
        let body = ["message_ids": messageIds]
        return try await post(path: "/messages/batch/\(status.rawValue)", body: body)
    }
}
