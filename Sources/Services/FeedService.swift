//
//  FeedService.swift
//
//
//  Created by Matt Gardner on 1/29/24.
//

import Foundation

internal class FeedService: KnockAPIService {
    func getUserFeedContent(userId: String, queryItems: [URLQueryItem]?, feedId: String) async throws -> Knock.Feed {
        try await get(path: "/users/\(userId)/feeds/\(feedId)", queryItems: queryItems)
    }
    
    func makeBulkStatusUpdate(feedId: String, type: Knock.KnockMessageStatusUpdateType, body: AnyEncodable?) async throws -> Knock.BulkOperation {
        try await post(path: "/channels/\(feedId)/messages/bulk/\(type.rawValue)", body: body)
    }
    
    func getFeedSettings(userId: String, feedId: String) async throws -> Knock.FeedSettings {
        try await get(path: "/users/\(userId)/feeds/\(feedId)/settings", queryItems: nil)
    }
}
