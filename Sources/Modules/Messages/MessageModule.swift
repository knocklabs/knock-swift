//
//  MessageModule.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal class MessageModule {
    let messageService = MessageService()
    
    internal func getMessage(messageId: String) async throws -> Knock.KnockMessage {
        do {
            let message = try await messageService.getMessage(messageId: messageId)
            KnockLogger.log(type: .debug, category: .message, message: "getMessage", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            KnockLogger.log(type: .error, category: .message, message: "getMessage", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func updateMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        do {
            let message = try await messageService.updateMessageStatus(messageId: messageId, status: status)
            KnockLogger.log(type: .debug, category: .message, message: "updateMessageStatus", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            KnockLogger.log(type: .error, category: .message, message: "updateMessageStatus", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func deleteMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        do {
            let message = try await messageService.deleteMessageStatus(messageId: messageId, status: status)
            KnockLogger.log(type: .debug, category: .message, message: "deleteMessageStatus", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            KnockLogger.log(type: .error, category: .message, message: "deleteMessageStatus", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func batchUpdateStatuses(messageIds: [String], status: Knock.KnockMessageStatusBatchUpdateType) async throws -> [Knock.KnockMessage] {
        do {
            let messages = try await messageService.batchUpdateStatuses(messageIds: messageIds, status: status)
            KnockLogger.log(type: .debug, category: .message, message: "batchUpdateStatuses", status: .success)
            return messages
        } catch let error {
            KnockLogger.log(type: .error, category: .message, message: "batchUpdateStatuses", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
}

public extension Knock {
    
    func getMessage(messageId: String) async throws -> KnockMessage {
        try await self.messageModule.getMessage(messageId: messageId)
    }
    
    func getMessage(messageId: String, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        Task {
            do {
                let message = try await getMessage(messageId: messageId)
                completionHandler(.success(message))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func updateMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType) async throws -> KnockMessage {
        try await self.messageModule.updateMessageStatus(messageId: message.id, status: status)
    }
    
    func updateMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        Task {
            do {
                let message = try await updateMessageStatus(message: message, status: status)
                completionHandler(.success(message))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func updateMessageStatus(messageId: String, status: KnockMessageStatusUpdateType) async throws -> KnockMessage {
        try await self.messageModule.updateMessageStatus(messageId: messageId, status: status)
    }
    
    func updateMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        Task {
            do {
                let message = try await updateMessageStatus(messageId: messageId, status: status)
                completionHandler(.success(message))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func deleteMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType) async throws -> KnockMessage {
        try await self.messageModule.deleteMessageStatus(messageId: message.id, status: status)
    }
    
    func deleteMessageStatus(message: KnockMessage, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        Task {
            do {
                let message = try await deleteMessageStatus(message: message, status: status)
                completionHandler(.success(message))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func deleteMessageStatus(messageId: String, status: KnockMessageStatusUpdateType) async throws -> KnockMessage {
        try await self.messageModule.updateMessageStatus(messageId: messageId, status: status)
    }
    
    func deleteMessageStatus(messageId: String, status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<KnockMessage, Error>) -> Void)) {
        Task {
            do {
                let message = try await deleteMessageStatus(messageId: messageId, status: status)
                completionHandler(.success(message))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    
    /**
     Batch status update for a list of messages
     
     - Parameters:
        - messageIds: the list of message ids: `[String]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func batchUpdateStatuses(messageIds: [String], status: KnockMessageStatusBatchUpdateType) async throws -> [KnockMessage] {
        try await self.messageModule.batchUpdateStatuses(messageIds: messageIds, status: status)
    }
    
    func batchUpdateStatuses(messageIds: [String], status: KnockMessageStatusBatchUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        Task {
            do {
                let messages = try await batchUpdateStatuses(messageIds: messageIds, status: status)
                completionHandler(.success(messages))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    /**
     Batch status update for a list of messages
     
     - Parameters:
        - messages: the list of messages `[KnockMessage]` to be updated
        - status: the new `Status`
        - completionHandler: the code to execute when the response is received
     */
    func batchUpdateStatuses(messages: [KnockMessage], status: KnockMessageStatusBatchUpdateType) async throws -> [KnockMessage] {
        let messageIds = messages.map{$0.id}
        return try await self.messageModule.batchUpdateStatuses(messageIds: messageIds, status: status)
    }
    
    func batchUpdateStatuses(messages: [KnockMessage], status: KnockMessageStatusBatchUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
        Task {
            do {
                let messages = try await batchUpdateStatuses(messages: messages, status: status)
                completionHandler(.success(messages))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
}
