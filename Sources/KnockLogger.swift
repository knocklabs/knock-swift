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

    internal static func log(type: LogType, category: LogCategory, message: String, description: String? = nil, status: LogStatus? = nil, errorMessage: String? = nil, additionalInfo: [String: String]? = nil) {
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
        let logger = Logger(subsystem: loggingSubsytem, category: category.rawValue.capitalized)
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
    }
}
