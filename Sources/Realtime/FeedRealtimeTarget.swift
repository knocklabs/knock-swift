//
//  FeedRealtimeTarget.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation

/// The parameters sent when joining a feed channel. The server uses them to decide which messages to push.
internal struct FeedChannelJoinParams: Encodable, Sendable, Equatable {
    var before: String?
    var after: String?
    var page_size: Int?
    var status: String?
    var source: String?
    var tenant: String?
    var has_tenant: Bool?
    var archived: String?
    var trigger_data: [String: AnyCodable]?

    init(options: Knock.FeedClientOptions) {
        self.before = options.before
        self.after = options.after
        self.page_size = options.page_size
        self.status = options.status?.rawValue
        self.source = options.source
        self.tenant = options.tenant
        self.has_tenant = options.has_tenant
        self.archived = options.archived?.rawValue
        self.trigger_data = options.trigger_data
    }
}

/// Everything needed to open a feed's realtime connection: which socket to connect to and which channel to join.
internal struct FeedRealtimeTarget: Sendable, Equatable {
    var socket: RealtimeSocketConfiguration
    var topic: String
    var joinParams: FeedChannelJoinParams

    static func make(
        baseUrl: String,
        publishableKey: String,
        userToken: String?,
        userId: String,
        feedId: String,
        options: Knock.FeedClientOptions
    ) -> FeedRealtimeTarget {
        FeedRealtimeTarget(
            socket: RealtimeSocketConfiguration(
                endpoint: websocketEndpoint(baseUrl: baseUrl),
                connectParams: ["api_key": publishableKey, "user_token": userToken ?? ""]
            ),
            topic: "feeds:\(feedId):\(userId)",
            joinParams: FeedChannelJoinParams(options: options)
        )
    }

    /// Maps the API base URL (e.g. `https://api.knock.app`) to the feed websocket endpoint (`wss://api.knock.app/ws/v1/websocket`).
    static func websocketEndpoint(baseUrl: String) -> String {
        var base = baseUrl
        while base.hasSuffix("/") {
            base.removeLast()
        }
        for (http, ws) in [("https://", "wss://"), ("http://", "ws://")] where base.lowercased().hasPrefix(http) {
            base = ws + base.dropFirst(http.count)
            break
        }
        return "\(base)/ws/v1/websocket"
    }
}
