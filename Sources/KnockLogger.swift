//
//  KnockLogger.swift
//
//
//  Created by Matt Gardner on 1/30/24.
//

import Foundation
import os.log

internal class KnockLogger {
    private static let loggingSubsytem = "knock-swift"
    
    internal var loggingDebugOptions: Knock.LoggingOptions = .errorsOnly

    internal func log(type: LogType, category: LogCategory, message: String, description: String? = nil, status: LogStatus? = nil, errorMessage: String? = nil, additionalInfo: [String: String]? = nil) {
        switch loggingDebugOptions {
        case .errorsOnly:
            if type != .error {
                return
            }
        case .errorsAndWarningsOnly:
            if type != .error || type != .warning {
                return
            }
        case .verbose:
            break
        case .none:
            return
        }
        
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
            for (key, value) in info {
                composedMessage += " | \(key): \(value)"
            }
        }

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

    internal enum LogStatus: String {
        case success
        case fail
    }
    
    internal enum LogType {
        case debug
        case info
        case error
        case warning
        case log
    }
    
    internal enum LogCategory: String {
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
        Knock.shared.logger.log(type: type, category: category, message: message, description: description, status: status, errorMessage: errorMessage, additionalInfo: additionalInfo)
    }
}
