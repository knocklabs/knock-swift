//
//  RealtimeLogger.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// Receives protocol-level diagnostics from the realtime socket.
internal struct RealtimeLogger: Sendable {
    /// Checked before building each message, so protocol logging costs nothing when disabled.
    var isEnabled: @Sendable () -> Bool
    var log: @Sendable (String) -> Void

    func callAsFunction(_ message: @autoclosure () -> String) {
        guard isEnabled() else { return }
        log(message())
    }

    static let disabled = RealtimeLogger(isEnabled: { false }, log: { _ in })
}
