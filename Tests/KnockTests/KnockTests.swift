//
//  KnockTests.swift
//  KnockTests
//
//  Created by Diego on 19/06/23.
//

import XCTest
@testable import Knock

final class KnockTests: XCTestCase {
    var knock: Knock!
    
    override func setUpWithError() throws {
        try? Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPublishableKeyError() throws {
        XCTAssertThrowsError(try Knock.shared.setup(publishableKey: "sk_123", pushChannelId: nil))
    }
    
    func testUserIdNilError() async throws {
        do {
            _ = try await knock.getUser()
            XCTFail("Expected getUser() to throw, but it did not.")
        } catch {}
    }
    
    func testUserDecoding() throws {
        let decoder = JSONDecoder()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        decoder.dateDecodingStrategy = .formatted(formatter)

        let jsonString = """
        {
            "id": "user-1",
            "custom1": 1,
            "extra2": {
                "a": 2,
                "b": 3,
                "c": {
                    "a1": true
                }
            }
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        
        let user = try decoder.decode(Knock.User.self, from: jsonData)
        XCTAssertNotNil(user, "decodes user is nil")
        XCTAssertNotNil(user.properties?["custom1"])
        XCTAssertEqual(user.properties!["custom1"], 1)
        
        let encoder = JSONEncoder()
        let reencodedJSON = try encoder.encode(user)
        let reencodedString = String(data: reencodedJSON, encoding: .utf8)!
        
        XCTAssertTrue(reencodedString.contains("extra2"))
        XCTAssertTrue(reencodedString.contains("a1"))
    }
}

// signing in before token has registered
// making a network request before Knock has been setup
// making a network request before Knock has received userid
// registering for push without channel id
// signIn, make sure we have everything
// signOut, make sure everything is cleared
// deadlock


