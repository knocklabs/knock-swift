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
            Knock.shared.log(type: .debug, category: .message, message: "getMessage", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            Knock.shared.log(type: .error, category: .message, message: "getMessage", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func updateMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        do {
            let message = try await messageService.updateMessageStatus(messageId: messageId, status: status)
            Knock.shared.log(type: .debug, category: .message, message: "updateMessageStatus", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            Knock.shared.log(type: .error, category: .message, message: "updateMessageStatus", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func deleteMessageStatus(messageId: String, status: Knock.KnockMessageStatusUpdateType) async throws -> Knock.KnockMessage {
        do {
            let message = try await messageService.deleteMessageStatus(messageId: messageId, status: status)
            Knock.shared.log(type: .debug, category: .message, message: "deleteMessageStatus", status: .success, additionalInfo: ["messageId": messageId])
            return message
        } catch let error {
            Knock.shared.log(type: .error, category: .message, message: "deleteMessageStatus", status: .fail, errorMessage: error.localizedDescription, additionalInfo: ["messageId": messageId])
            throw error
        }
    }
    
    internal func batchUpdateStatuses(messageIds: [String], status: Knock.KnockMessageStatusUpdateType) async throws -> [Knock.KnockMessage] {
        do {
            let messages = try await messageService.batchUpdateStatuses(messageIds: messageIds, status: status)
            Knock.shared.log(type: .debug, category: .message, message: "batchUpdateStatuses", status: .success)
            return messages
        } catch let error {
            Knock.shared.log(type: .error, category: .message, message: "batchUpdateStatuses", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
}

public extension Knock {
    
    /**
     Returns the KnockMessage for the associated messageId.
     https://docs.knock.app/reference#get-a-message
     
     - Parameters:
        - messageId: The messageId for the KnockMessage.
     */
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
    
    /**
     Marks the given message with the provided status, recording an event in the process.
     https://docs.knock.app/reference#update-message-status
     
     - Parameters:
        - message: The KnockMessage that you want to update.
        - status: The new status to be associated with the KnockMessage.
     */
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
    
    /**
     Marks the given message with the provided status, recording an event in the process.
     https://docs.knock.app/reference#update-message-status

     - Parameters:
        - messageId: The id for the KnockMessage that you want to update.
        - status: The new status to be associated with the KnockMessage.
     */
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
    
    /**
     Un-marks the given status on a message, recording an event in the process.
     https://docs.knock.app/reference#undo-message-status
     
     - Parameters:
        - message: The KnockMessage that you want to update.
        - status: The new status to be associated with the KnockMessage.
     */
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
    
    /**
     Un-marks the given status on a message, recording an event in the process.
     https://docs.knock.app/reference#undo-message-status
     
     - Parameters:
        - preferenceId: The preferenceId for the PreferenceSet.
        - preferenceSet: PreferenceSet with updated properties.
     */
    func deleteMessageStatus(messageId: String, status: KnockMessageStatusUpdateType) async throws -> KnockMessage {
        try await self.messageModule.deleteMessageStatus(messageId: messageId, status: status)
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
     https://docs.knock.app/reference#batch-update-message-status
     
     - Parameters:
        - messageIds: the list of message ids: `[String]` to be updated
        - status: the new `Status`
     
     *Note:* Knock scopes this batch rate limit by message_ids and status. This allows for 1 update per second per message per status.
     */
    func batchUpdateStatuses(messageIds: [String], status: KnockMessageStatusUpdateType) async throws -> [KnockMessage] {
        try await self.messageModule.batchUpdateStatuses(messageIds: messageIds, status: status)
    }
    
    func batchUpdateStatuses(messageIds: [String], status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
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
     https://docs.knock.app/reference#batch-update-message-status
     
     - Parameters:
        - messages: the list of messages `[KnockMessage]` to be updated
        - status: the new `Status`
     
     *Note:* Knock scopes this batch rate limit by message_ids and status. This allows for 1 update per second per message per status.
     */
    func batchUpdateStatuses(messages: [KnockMessage], status: KnockMessageStatusUpdateType) async throws -> [KnockMessage] {
        let messageIds = messages.map{$0.id}
        return try await self.messageModule.batchUpdateStatuses(messageIds: messageIds, status: status)
    }
    
    func batchUpdateStatuses(messages: [KnockMessage], status: KnockMessageStatusUpdateType, completionHandler: @escaping ((Result<[KnockMessage], Error>) -> Void)) {
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
