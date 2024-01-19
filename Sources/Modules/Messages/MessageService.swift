//
//  MessageService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation

public extension Knock {
    
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
     Batch status update for a list of messages
     
     - Parameters:
        - messageIds: the list of message ids: `[String]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func batchUpdateStatuses(messageIds: [String], status: KnockMessageStatusBatchUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
    
    /**
     Batch status update for a list of messages
     
     - Parameters:
        - messages: the list of messages `[KnockMessage]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func batchUpdateStatuses(messages: [KnockMessage], status: KnockMessageStatusBatchUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        let messageIds = messages.map{$0.id}
        let body = [
            "message_ids": messageIds
        ]
        
        api.decodeFromPost([KnockMessage].self, path: "/messages/batch/\(status.rawValue)", body: body, then: completionHandler)
    }
}
