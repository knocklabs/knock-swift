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
    
    func testPrepareTokensWithNoChannelData() {
        let newToken = "newToken"
        let previousTokens = [newToken]
        let tokens = Knock.shared.channelModule.getTokenDataForServer(newToken: newToken, previousTokens: previousTokens, channelDataTokens: [], forDeregistration: false)
        XCTAssertEqual(tokens, [newToken])
    }
    
    func testPrepareTokensWithDuplicateToken() async {
        let newToken = "newToken"
        let previousTokens = [newToken]
        let channelTokens = [newToken]

        let tokens = Knock.shared.channelModule.getTokenDataForServer(newToken: newToken, previousTokens: previousTokens, channelDataTokens: channelTokens, forDeregistration: false)
        XCTAssertEqual(tokens, [newToken])
    }
    
    func testPrepareTokensWithOldTokensNeedingToBeRemoved() {
        let newToken = "newToken"
        let previousTokens = ["1234", newToken]
        let channelTokens = ["1234", "12345"]

        let tokens = Knock.shared.channelModule.getTokenDataForServer(newToken: newToken, previousTokens: previousTokens, channelDataTokens: channelTokens, forDeregistration: false)
        XCTAssertEqual(tokens, ["12345", newToken])
    }
    
    func testPrepareTokensWithFirstTimeToken() async {
        let newToken = "newToken"
        let previousTokens = ["1234", newToken, "1"]
        let channelTokens = ["1234", "12345"]

        let tokens = Knock.shared.channelModule.getTokenDataForServer(newToken: newToken, previousTokens: previousTokens, channelDataTokens: channelTokens, forDeregistration: false)
        XCTAssertEqual(tokens, ["12345", newToken])
    }
    
    func testPrepareTokensForDeregistration() async {
        let newToken = "newToken"
        let previousTokens = ["1234", newToken, "1"]
        let channelTokens = ["1234", "12345", newToken]

        let tokens = Knock.shared.channelModule.getTokenDataForServer(newToken: newToken, previousTokens: previousTokens, channelDataTokens: channelTokens, forDeregistration: true)
        XCTAssertEqual(tokens, ["12345"])
    }

}
