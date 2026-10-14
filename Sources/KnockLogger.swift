//
//  KnockLogger.swift
//
//
//  Created by Matt Gardner on 1/30/24.
//

import Foundation
import os.log

internal final class KnockLogger: Sendable {
    private static let loggingSubsytem = "knock-swift"

    private let options = LockIsolated(Knock.LoggingOptions.errorsOnly)

    internal var loggingDebugOptions: Knock.LoggingOptions {
        get { options.value }
        set { options.setValue(newValue) }
    }

    internal func shouldLog(_ type: LogType) -> Bool {
        Self.shouldLog(type, options: loggingDebugOptions)
    }

    internal static func shouldLog(_ type: LogType, options: Knock.LoggingOptions) -> Bool {
        switch options {
        case .errorsOnly:
            return type == .error
        case .errorsAndWarningsOnly:
            return type == .error || type == .warning
        case .verbose:
            return true
        case .none:
            return false
        }
    }

    internal func log(type: LogType, category: LogCategory, message: String, description: String? = nil, status: LogStatus? = nil, errorMessage: String? = nil, additionalInfo: [String: String]? = nil) {
        guard shouldLog(type) else { return }

        let composedMessage = Self.composeMessage(message: message, description: description, status: status, errorMessage: errorMessage, additionalInfo: additionalInfo)

        // Use the Logger API for logging
        let logger = Logger(subsystem: KnockLogger.loggingSubsytem, category: category.rawValue.capitalized)
        switch type {
        case .debug:
            logger.debug("\(composedMessage)")
        case .info:
            logger.info("\(composedMessage)")
        case .error:
            logger.error("\(composedMessage)")
        case .warning:
            logger.warning("\(composedMessage)")
        default:
            logger.log("\(composedMessage)")
        }
    }

    internal static func composeMessage(message: String, description: String? = nil, status: LogStatus? = nil, errorMessage: String? = nil, additionalInfo: [String: String]? = nil) -> String {
        var composedMessage = "[Knock] "
        composedMessage += message
        if let description = description {
            composedMessage += " | description: \(description)"
        }
        if let status = status {
            composedMessage += " | Status: \(status.rawValue)"
        }
        if let errorMessage = errorMessage {
            composedMessage += " | Error: \(errorMessage)"
        }
        if let info = additionalInfo {
            for (key, value) in info.sorted(by: { $0.key < $1.key }) {
                composedMessage += " | \(key): \(value)"
            }
        }
        return composedMessage
    }

    internal enum LogStatus: String, Sendable {
        case success
        case fail
    }
    
    internal enum LogType: Sendable {
        case debug
        case info
        case error
        case warning
        case log
    }
    
    internal enum LogCategory: String, Sendable {
        case user
        case feed
        case channel
        case preferences
        case networking
        case pushNotification
        case message
        case general
        case appDelegate
    }
}

extension Knock {
    internal func log(type: KnockLogger.LogType, category: KnockLogger.LogCategory, message: String, description: String? = nil, status: KnockLogger.LogStatus? = nil, errorMessage: String? = nil, additionalInfo: [String: String]? = nil) {
        logger.log(type: type, category: category, message: message, description: description, status: status, errorMessage: errorMessage, additionalInfo: additionalInfo)
    }
}
