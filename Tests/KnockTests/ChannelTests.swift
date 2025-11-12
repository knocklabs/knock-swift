//
//  ChannelTests.swift
//
//
//  Created by Matt Gardner on 2/5/24.
//

import XCTest
@testable import Knock

final class ChannelTests: XCTestCase {
    var channelModule: ChannelModule!

    override func setUpWithError() throws {
        channelModule = ChannelModule()
    }

    override func tearDownWithError() throws {
        channelModule = nil
    }

    func testFilterTokensOut_RemovesMatchingTokens() {
        let devices: [Knock.Device] = [
            Knock.Device(token: "a", locale: "en_US", timezone: "UTC"),
            Knock.Device(token: "b", locale: "en_US", timezone: "UTC"),
            Knock.Device(token: "c", locale: "en_US", timezone: "UTC"),
        ]
        let result = channelModule.filterTokensOutFromDevices(
            devices: devices, targetTokens: ["a", "b"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.token, "c")
    }

    func testFilterTokensOut_LeavesUnmatchedTokens() {
        let devices: [Knock.Device] = [
            Knock.Device(token: "x", locale: "en_US", timezone: "UTC")
        ]
        let result = channelModule.filterTokensOutFromDevices(devices: devices, targetTokens: ["y"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.token, "x")
    }

    func testFilterTokensOut_WithEmptyInput_ReturnsEmpty() {
        let result = channelModule.filterTokensOutFromDevices(devices: [], targetTokens: ["a"])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - addTokenToDevices

    func testAddToken_AddsNewToken() {
        let devices: [Knock.Device] = [
            Knock.Device(token: "a", locale: "en_US", timezone: "UTC")
        ]
        let result = channelModule.addTokenToDevices(devices: devices, newToken: "b")
        XCTAssertEqual(result.count, 2)
        let tokens = result.map { $0.token }
        XCTAssertTrue(tokens.contains("b"))
    }

    func testAddToken_DoesNotAddDuplicateToken() {
        let devices: [Knock.Device] = [
            Knock.Device(token: "a", locale: "en_US", timezone: "UTC")
        ]
        let result = channelModule.addTokenToDevices(devices: devices, newToken: "a")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.token, "a")
    }

    func testAddToken_PreservesExistingDevices() {
        let devices: [Knock.Device] = [
            Knock.Device(token: "a", locale: "en_US", timezone: "UTC")
        ]
        let result = channelModule.addTokenToDevices(devices: devices, newToken: "b")
        let tokens = result.map { $0.token }
        XCTAssertEqual(tokens.sorted(), ["a", "b"])
    }

    func testBuildDeviceObject_HasExpectedFields() {
        let device = channelModule.buildDeviceObject(token: "abc123")
        XCTAssertEqual(device.token, "abc123")
        XCTAssertNotNil(device.locale)
        XCTAssertNotNil(device.timezone)
    }
}
