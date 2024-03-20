//
//  AuthenticationTests.swift
//
//
//  Created by Matt Gardner on 2/2/24.
//

import XCTest
@testable import Knock

final class AuthenticationTests: XCTestCase {
    
    override func setUpWithError() throws {
        Task {
            try? await Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
        }
    }

    override func tearDownWithError() throws {
        Knock.shared.resetInstanceCompletely()
    }
    

    func testSignIn() async throws {
        let userName = "testUserName"
        let userToken = "testUserToken"
        await Knock.shared.signIn(userId: userName, userToken: userToken)
        
        let knockUserName = await Knock.shared.environment.getUserId()
        let knockUserToken = await Knock.shared.environment.getUserToken()
        XCTAssertEqual(userName, knockUserName)
        XCTAssertEqual(userToken, knockUserToken)
    }
    
    func testSignOut() async throws {
        await Knock.shared.signIn(userId: "testUserName", userToken: "testUserToken")
        await Knock.shared.environment.setDeviceToken("test")
        
        await Knock.shared.authenticationModule.clearDataForSignOut()
        
        let userId = await Knock.shared.environment.getUserId()
        let userToken = await Knock.shared.environment.getUserToken()
        let publishableKey = await Knock.shared.environment.getPublishableKey()
        let deviceToken = await Knock.shared.environment.getDeviceToken()
        
        XCTAssertEqual(userId, nil)
        XCTAssertEqual(userToken, nil)
        XCTAssertEqual(publishableKey, "pk_123")
        XCTAssertEqual(deviceToken, "test")
    }
}
