//
//  KnockTests.swift
//  KnockTests
//
//  Created by Diego on 19/06/23.
//

import XCTest
@testable import Knock

final class KnockTests: XCTestCase {
    override func setUpWithError() throws {
        Task {
            try? await Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
        }
    }

    override func tearDownWithError() throws {
        Knock.shared.resetInstanceCompletely()
    }
    
    func testPublishableKeyError() async throws {
        do {
            let _ = try await Knock.shared.setup(publishableKey: "sk_123", pushChannelId: nil)
            XCTFail("Expected function to throw an error, but it did not.")
        } catch let error as Knock.KnockError {
            XCTAssertEqual(error, Knock.KnockError.wrongKeyError, "The error should be wrongKeyError")
        } catch {
            XCTFail("Expected KnockError, but received a different error.")
        }
    }
    
    func testMakingNetworkRequestBeforeKnockSetUp() async {
        try! tearDownWithError()
        await Knock.shared.environment.setUserInfo(userId: "test", userToken: nil)
        do {
            let _ = try await Knock.shared.getUser()
            XCTFail("Expected function to throw an error, but it did not.")
        } catch let error as Knock.KnockError {
            XCTAssertEqual(error, Knock.KnockError.knockNotSetup, "The error should be knockNotSetup")
        } catch {
            XCTFail("Expected KnockError, but received a different error.")
        }
    }
    
    func testMakingNetworkRequestBeforeSignIn() async {
        do {
            let _ = try await Knock.shared.getUser()
            XCTFail("Expected function to throw an error, but it did not.")
        } catch let error as Knock.KnockError {
            XCTAssertEqual(error, Knock.KnockError.userIdNotSetError, "The error should be userIdNotSetError")
        } catch {
            XCTFail("Expected KnockError, but received a different error.")
        }
    }
    
    
}
