//
//  FeedService.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal final class FeedModule: Sendable {
    let feedId: String
    let realtime: FeedRealtimeSession
    private let feedOptions: Knock.FeedClientOptions
    private let feedService = FeedService()

    /// - Parameter environment: Read on every connect, so the socket always uses the current user and token.
    internal init(
        feedId: String,
        options: Knock.FeedClientOptions,
        environment: @escaping @Sendable () -> KnockEnvironment = { Knock.shared.environment },
        socketFactory: RealtimeSocketFactory? = nil,
        realtimePolicy: FeedRealtimeSession.Policy = .default
    ) {
        self.feedId = feedId
        self.feedOptions = options
        self.realtime = FeedRealtimeSession(
            socketFactory: socketFactory ?? FeedModule.phoenixNectarSocketFactory(environment: environment),
            targetProvider: { overrides in
                try await FeedModule.realtimeTarget(
                    feedId: feedId,
                    options: options.mergeOptions(options: overrides),
                    environment: environment()
                )
            },
            policy: realtimePolicy,
            logger: FeedModule.realtimeLogger
        )
    }

    /// Resolves the socket and channel for the signed-in user from the current Knock environment.
    static func realtimeTarget(feedId: String, options: Knock.FeedClientOptions, environment: KnockEnvironment) async throws -> FeedRealtimeTarget {
        let userId: String
        do {
            userId = try await environment.getSafeUserId()
        } catch {
            Knock.shared.log(type: .error, category: .feed, message: "FeedManager", status: .fail, errorMessage: "Must sign user in before connecting to the feed")
            throw error
        }
        return FeedRealtimeTarget.make(
            baseUrl: await environment.getBaseUrl(),
            publishableKey: try await environment.getSafePublishableKey(),
            userToken: await environment.getUserToken(),
            userId: userId,
            feedId: feedId,
            options: options
        )
    }

    static let realtimeLogger = RealtimeLogger(
        isEnabled: { Knock.shared.logger.shouldLog($0) },
        log: { type, message in
            Knock.shared.log(type: type, category: .feed, message: "FeedRealtime", description: message)
        }
    )

    /// Reconnects send the latest user token, so a token refreshed with `signIn` is used without reconnecting by hand.
    static func phoenixNectarSocketFactory(environment: @escaping @Sendable () -> KnockEnvironment) -> RealtimeSocketFactory {
        { configuration in
            let publishableKey = configuration.connectParams["api_key"] ?? ""
            return try PhoenixNectarRealtimeSocket(
                endpoint: configuration.endpoint,
                connectParams: {
                    FeedRealtimeTarget.connectParams(publishableKey: publishableKey, userToken: environment().currentUserToken)
                },
                logger: realtimeLogger
            )
        }
    }

    func getUserFeedContent(options: Knock.FeedClientOptions? = nil) async throws -> Knock.Feed {
        let mergedOptions = feedOptions.mergeOptions(options: options)
        
        let triggerDataJSON = Knock.encodeGenericDataToJSON(data: mergedOptions.trigger_data)
        
        let queryItems = [
            URLQueryItem(name: "page_size", value: (mergedOptions.page_size != nil) ? "\(mergedOptions.page_size!)" : nil),
            URLQueryItem(name: "after", value: mergedOptions.after),
            URLQueryItem(name: "before", value: mergedOptions.before),
            URLQueryItem(name: "source", value: mergedOptions.source),
            URLQueryItem(name: "tenant", value: mergedOptions.tenant),
            URLQueryItem(name: "has_tenant", value: mergedOptions.has_tenant.stringOrNil()),
            URLQueryItem(name: "status", value: (mergedOptions.status != nil) ? mergedOptions.status?.rawValue : ""),
            URLQueryItem(name: "archived", value: (mergedOptions.archived != nil) ? mergedOptions.archived?.rawValue : ""),
            URLQueryItem(name: "trigger_data", value: triggerDataJSON),
            URLQueryItem(name: "locale", value: mergedOptions.locale)
        ]
        
        do {
            let feed = try await feedService.getUserFeedContent(userId: Knock.shared.environment.getSafeUserId(), queryItems: queryItems, feedId: feedId)
            Knock.shared.log(type: .debug, category: .feed, message: "getUserFeedContent", status: .success)
            return feed
        } catch let error {
            Knock.shared.log(type: .error, category: .feed, message: "getUserFeedContent", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    func makeBulkStatusUpdate(type: Knock.KnockMessageStatusUpdateType, options: Knock.FeedClientOptions) async throws -> Knock.BulkOperation {
        // TODO: check https://docs.knock.app/reference#bulk-update-channel-message-status
        // older_than: ISO-8601, check milliseconds
        // newer_than: ISO-8601, check milliseconds
        // delivery_status: one of `queued`, `sent`, `delivered`, `delivery_attempted`, `undelivered`, `not_sent`
        // engagement_status: one of `seen`, `unseen`, `read`, `unread`, `archived`, `unarchived`, `interacted`
        // Also check if the parameters sent here are valid
        let mergedOptions = feedOptions.mergeOptions(options: options)

        let userId = try await Knock.shared.environment.getSafeUserId()
        let body: AnyEncodable = [
            "user_ids": [userId],
            "engagement_status": mergedOptions.status != nil && mergedOptions.status != .all ? mergedOptions.status!.rawValue : "",
            "archived": mergedOptions.archived?.rawValue ?? "",
            "has_tenant": mergedOptions.has_tenant ?? "",
            "tenants": (mergedOptions.tenant != nil) ? [mergedOptions.tenant!] : ""
        ]
        do {
            let op = try await feedService.makeBulkStatusUpdate(feedId: feedId, type: type, body: body)
            Knock.shared.log(type: .debug, category: .feed, message: "makeBulkStatusUpdate", status: .success)
            return op
        } catch let error {
            Knock.shared.log(type: .error, category: .feed, message: "makeBulkStatusUpdate", status: .fail, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    internal func getFeedSettings() async throws -> Knock.FeedSettings? {
        guard let userId = try? await Knock.shared.environment.getSafeUserId() else { return nil }
        return try? await feedService.getFeedSettings(userId: userId, feedId: feedId)
    }
}
