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
        try? Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
    }

    override func tearDownWithError() throws {
        Knock.shared = Knock()
    }
    

    func testSignIn() async throws {
        let userName = "testUserName"
        let userToken = "testUserToken"
        await Knock.shared.signIn(userId: userName, userToken: userToken)
 
        XCTAssertEqual(userName, Knock.shared.environment.userId)
        XCTAssertEqual(userToken, Knock.shared.environment.userToken)
    }
    
    func testSignOut() async throws {
        await Knock.shared.signIn(userId: "testUserName", userToken: "testUserToken")
        Knock.shared.environment.userDevicePushToken = "test"
        Knock.shared.environment.userDevicePushToken = "test"
        Knock.shared.environment.userDevicePushToken = "test"
        
        Knock.shared.authenticationModule.clearDataForSignOut()
        
        XCTAssertEqual(Knock.shared.environment.userId, nil)
        XCTAssertEqual(Knock.shared.environment.userToken, nil)
        XCTAssertEqual(Knock.shared.environment.publishableKey, "pk_123")
        XCTAssertEqual(Knock.shared.environment.userDevicePushToken, "test")
    }
}
