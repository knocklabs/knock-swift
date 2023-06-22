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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        // check that initializing the client with a secret key prefix throws
        XCTAssertThrowsError(try Knock(publishableKey: "sk_123", userId: ""))
    }
    
    func testUserDecoding1() throws {
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

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let _ = try! Knock(publishableKey: "pk_123", userId: "u-123")
        }
    }

}
