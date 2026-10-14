//
//  KnockLoggerTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import Testing
@testable import Knock

@Suite("KnockLogger")
struct KnockLoggerTests {
    @Test(arguments: [
        (Knock.LoggingOptions.errorsOnly, [KnockLogger.LogType.error]),
        (.errorsAndWarningsOnly, [.error, .warning]),
        (.verbose, [.debug, .info, .error, .warning, .log]),
        (.none, []),
    ])
    func loggingOptionsSelectLogTypes(options: Knock.LoggingOptions, logged: [KnockLogger.LogType]) {
        let all: [KnockLogger.LogType] = [.debug, .info, .error, .warning, .log]
        #expect(all.filter { KnockLogger.shouldLog($0, options: options) } == logged)
    }

    @Test func messagesIncludeEveryDetailInAStableOrder() {
        let message = KnockLogger.composeMessage(
            message: "Joined",
            description: "feeds:1",
            status: .success,
            errorMessage: "none",
            additionalInfo: ["b": "2", "a": "1"]
        )
        #expect(message == "[Knock] Joined | description: feeds:1 | Status: success | Error: none | a: 1 | b: 2")
        #expect(KnockLogger.composeMessage(message: "Joined") == "[Knock] Joined")
    }

    @Test func realtimeLoggerOnlyBuildsMessagesForEnabledLevels() {
        let logged = LockIsolated<[String]>([])
        let built = LockIsolated(0)
        let logger = RealtimeLogger(
            isEnabled: { $0 == .error },
            log: { _, message in logged.withLock { $0.append(message) } }
        )
        func message(_ text: String) -> String {
            built.withLock { $0 += 1 }
            return text
        }

        logger(.debug, message("debug"))
        logger(.error, message("error"))

        #expect(logged.value == ["error"])
        #expect(built.value == 1)
    }
}
