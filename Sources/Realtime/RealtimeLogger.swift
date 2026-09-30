//
//  RealtimeLogger.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// Receives diagnostics from the realtime session and socket.
internal struct RealtimeLogger: Sendable {
    /// Checked before building each message, so logging costs nothing when the level is disabled.
    var isEnabled: @Sendable (KnockLogger.LogType) -> Bool
    var log: @Sendable (KnockLogger.LogType, String) -> Void

    func callAsFunction(_ type: KnockLogger.LogType, _ message: @autoclosure () -> String) {
        guard isEnabled(type) else { return }
        log(type, message())
    }

    static let disabled = RealtimeLogger(isEnabled: { _ in false }, log: { _, _ in })
}
