//
//  ChannelService.swift
//
//
//  Created by Diego on 30/05/23.
//

import Foundation
import OSLog

internal class ChannelService: KnockAPIService {
    
    func getUserChannelData(userId: String, channelId: String) async throws -> Knock.ChannelData {
        try await get(path: "/users/\(userId)/channel_data/\(channelId)", queryItems: nil)
    }
    
    func updateUserChannelData(userId: String, channelId: String, data: AnyEncodable) async throws -> Knock.ChannelData {
        let body = ["data": data]
        return try await put(path: "/users/\(userId)/channel_data/\(channelId)", body: body)
    }
}
