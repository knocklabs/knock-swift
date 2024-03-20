//
//  UserTests.swift
//
//
//  Created by Matt Gardner on 1/31/24.
//

import XCTest
@testable import Knock

final class UserTests: XCTestCase {
    
    override func setUpWithError() throws {
        Task {
            try? await Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
        }
    }

    override func tearDownWithError() throws {
        Knock.shared.resetInstanceCompletely()
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
