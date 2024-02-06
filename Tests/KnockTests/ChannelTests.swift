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
        try? Knock.shared.setup(publishableKey: "pk_123", pushChannelId: "test")
    }

    override func tearDownWithError() throws {
        Knock.shared = Knock()
    }

}
