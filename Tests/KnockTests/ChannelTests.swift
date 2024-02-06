//
//  ChannelTests.swift
//  
//
//  Created by Matt Gardner on 2/5/24.
//

import XCTest
@testable import Knock

final class ChannelTests: XCTestCase {

    override func setUpWithError() throws {
        Task {
            try? await Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
        }
    }

    override func tearDownWithError() throws {
        Knock.shared.resetInstanceCompletely()
    }
    
    func testPrepareTokensWithNoChannelData() async {
        let newToken = "newToken"
        let tokens = await Knock.shared.channelModule.prepareTokenDataForRegistration(newToken: newToken, newChannelId: "newChannelId", existingChannelData: nil)
        XCTAssertEqual(tokens, [newToken])
    }
    
    func testPrepareTokensWithDuplicateToken() async {
        let newToken = "123"
        let channelData = Knock.ChannelData(channel_id: "newChannelId", data: ["tokens": [newToken]])
        let tokens = await Knock.shared.channelModule.prepareTokenDataForRegistration(newToken: newToken, newChannelId: "newChannelId", existingChannelData: channelData)
        XCTAssertEqual(tokens, nil)
    }
    
    func testPrepareTokensWithOldTokenNeedingToBeRemoved() async {
        let newToken = "123"
        let oldToken = "1234"
        let channelId = "test"
        await Knock.shared.environment.setDeviceToken(oldToken)
        try! await Knock.shared.setup(publishableKey: "pk_123", pushChannelId: channelId)

        let channelData = Knock.ChannelData(channel_id: channelId, data: ["tokens": [oldToken]])
        let tokens = await Knock.shared.channelModule.prepareTokenDataForRegistration(newToken: newToken, newChannelId: channelId, existingChannelData: channelData)
        XCTAssertEqual(tokens, [newToken])
    }
    
    func testPrepareTokensWithOldTokenNotNeedingToBeRemoved() async {
        let newToken = "123"
        let oldToken = "1234"
        let oldChannelId = "oldChannelId"
        let channelId = "newChannelId"
        await Knock.shared.environment.setDeviceToken(oldToken)
        await Knock.shared.environment.setPushChannelId(oldChannelId)

        let channelData = Knock.ChannelData(channel_id: channelId, data: ["tokens": [oldToken]])
        let tokens = await Knock.shared.channelModule.prepareTokenDataForRegistration(newToken: newToken, newChannelId: channelId, existingChannelData: channelData)
        XCTAssertEqual(tokens, [oldToken, newToken])
    }
    
    func testPrepareTokensWithFirstTimeToken() async {
        let newToken = "newToken"
        let channelData = Knock.ChannelData(channel_id: "newChannelId", data: ["tokens": []])
        let tokens = await Knock.shared.channelModule.prepareTokenDataForRegistration(newToken: newToken, newChannelId: "newChannelId", existingChannelData: channelData)
        XCTAssertEqual(tokens, [newToken])
    }

}
