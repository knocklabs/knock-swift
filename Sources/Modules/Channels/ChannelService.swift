//
//  ChannelService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation
import OSLog

internal class ChannelService: KnockAPIService {
    
    func getUserChannelData(channelId: String) async throws -> Knock.ChannelData {
        try await get(path: "/users/\(getSafeUserId())/channel_data/\(channelId)", queryItems: nil)
    }
    
    func updateUserChannelData(channelId: String, data: AnyEncodable) async throws -> Knock.ChannelData {
        let body = ["data": data]
        return try await put(path: "/users/\(getSafeUserId())/channel_data/\(channelId)", body: body)
    }
}
