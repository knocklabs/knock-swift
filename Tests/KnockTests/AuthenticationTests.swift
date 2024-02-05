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
        Task {
            try? await Knock.shared.resetInstance()
        }
    }

    func testSignIn() throws {
        let userName = "testUserName"
        let userToken = "testUserToken"
        Task {
            try! await Knock.shared.signIn(userId: userName, userToken: userToken)
        }
        XCTAssertTrue(Knock.shared.environment.userId == userName && Knock.shared.environment.userToken == userToken)
    }
    
    func testSignOut() throws {
//        XCTAssertTrue(Knock.shared.environment.userId == userName && Knock.shared.environment.userToken == userToken)
//        XCTAssertThrowsError(try Knock.shared.setup(publishableKey: "sk_123", pushChannelId: nil))
    }
}
