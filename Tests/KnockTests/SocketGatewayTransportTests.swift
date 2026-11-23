//
//  SocketGatewayTransportTests.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation
import Testing
@testable import Knock
import PhoenixNectar

/// A scripted base transport.
actor FakeBaseTransport: PhoenixTransport {
    let url: URL
    private(set) var connectHeaders: [[String: String]] = []
    private(set) var disconnects: [(Int, String?)] = []
    private(set) var sentText: [Data] = []
    private var state = PhoenixTransportReadyState.closed
    private var continuations: [AsyncStream<TransportEvent>.Continuation] = []

    init(url: URL) { self.url = url }

    func readyState() async -> PhoenixTransportReadyState { state }

    func events(bufferingPolicy: AsyncStream<TransportEvent>.Continuation.BufferingPolicy) async -> AsyncStream<TransportEvent> {
        let (stream, continuation) = AsyncStream<TransportEvent>.makeStream(bufferingPolicy: bufferingPolicy)
        continuations.append(continuation)
        return stream
    }

    func connect(with headers: [String: String]) async {
        connectHeaders.append(headers)
        state = .connecting
    }

    func disconnect(code: Int, reason: String?) async {
        disconnects.append((code, reason))
        state = .closed
        emit(.close(code, reason))
        continuations.forEach { $0.finish() }
    }

    func sendText(data: Data) async { sentText.append(data) }
    func sendBinary(data: Data) async {}

    func emit(_ event: TransportEvent) {
        if case .open = event { state = .open }
        continuations.forEach { $0.yield(event) }
    }

    func end() { continuations.forEach { $0.finish() } }
}

@Suite("SocketGatewayTransport", .serialized)
struct SocketGatewayTransportTests {
    final class Harness: Sendable {
        let bases = LockIsolated<[FakeBaseTransport]>([])
        let invalidations = LockIsolated(0)
        let unsupportedModes = LockIsolated<[String?]>([])
        let gate = AsyncGate()
        let result = LockIsolated<Result<SocketGatewayConnection, Error>>(
            .success(SocketGatewayConnection(signedUrl: "wss://gateway.knock.app/ws?sig=abc", expiresAt: .distantFuture))
        )
        let fetchCount = LockIsolated(0)
        let holdFetch: Bool

        init(holdFetch: Bool = false) { self.holdFetch = holdFetch }

        func makeTransport(url: String = "wss://api.knock.app/ws/v1/websocket?vsn=2.0.0&api_key=pk_test&user_token=tok") -> SocketGatewayTransport {
            SocketGatewayTransport(
                url: URL(string: url)!,
                baseTransport: { [bases] url in
                    let base = FakeBaseTransport(url: url)
                    bases.withLock { $0.append(base) }
                    return base
                },
                fetchConnectUrl: { [self] in
                    fetchCount.withLock { $0 += 1 }
                    if holdFetch { await gate.wait() }
                    try Task.checkCancellation()
                    return try result.value.get()
                },
                onConnectUrlInvalid: { [invalidations] in invalidations.withLock { $0 += 1 } },
                onUnsupportedMode: { [unsupportedModes] mode in unsupportedModes.withLock { $0.append(mode) } }
            )
        }

        var base: FakeBaseTransport? { bases.value.first }
    }

    @Test func connectsToTheSignedUrlWithTheUnsignedQueryAppended() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        await transport.connect(with: ["X-Test": "1"])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        let base = try #require(harness.base)
        #expect(await base.url.absoluteString == "wss://gateway.knock.app/ws?sig=abc&vsn=2.0.0&api_key=pk_test&user_token=tok")
        #expect(await base.connectHeaders == [["X-Test": "1"]])
    }

    @Test func usesAQuestionMarkWhenTheSignedUrlHasNoQuery() {
        #expect(SocketGatewayTransport.url(signedUrl: "wss://g/ws", unsignedQuery: "a=1")?.absoluteString == "wss://g/ws?a=1")
        #expect(SocketGatewayTransport.url(signedUrl: "wss://g/ws?a=1", unsignedQuery: "a=1")?.absoluteString == "wss://g/ws?a=1&a=1")
        #expect(SocketGatewayTransport.url(signedUrl: "wss://g/ws", unsignedQuery: nil)?.absoluteString == "wss://g/ws")
    }

    @Test func forwardsEventsAndReadyState() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        #expect(await transport.readyState() == .closed)

        await transport.connect(with: [:])
        #expect(await transport.readyState() == .connecting)
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        let base = try #require(harness.base)
        await base.emit(.open)
        await base.emit(.message("hi"))
        try await waitUntil("events") { events.values.count == 2 }
        #expect(events.values == [.open, .message("hi")])
        #expect(await transport.readyState() == .open)

        await transport.sendText(data: Data("ping".utf8))
        #expect(await base.sentText == [Data("ping".utf8)])
        #expect(harness.invalidations.value == 0)
    }

    @Test func disconnectDuringTheFetchNeverOpensAWebSocket() async throws {
        let harness = Harness(holdFetch: true)
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])
        try await waitUntil("fetch") { harness.fetchCount.value == 1 }

        await transport.disconnect(code: 1000, reason: nil)
        await harness.gate.open()

        try await waitUntil("finished") { events.isFinished }
        #expect(events.values == [.close(1000, nil)])
        #expect(harness.bases.value.isEmpty)
        #expect(await transport.readyState() == .closed)
    }

    @Test func disconnectingTwiceClosesOnce() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        await transport.disconnect(code: 1001, reason: "bye")
        await transport.disconnect(code: 1001, reason: "bye")

        try await waitUntil("finished") { events.isFinished }
        #expect(events.values == [.close(1001, "bye")])
        #expect(await harness.base?.disconnects.count == 1)
        #expect(harness.invalidations.value == 0)
    }

    @Test func aFailedFetchEmitsAnErrorThenAnAbnormalClose() async throws {
        let harness = Harness()
        harness.result.setValue(.failure(TestError(reason: "offline")))
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])

        try await waitUntil("finished") { events.isFinished }
        #expect(events.values == [.error("offline"), .close(1006, "gateway_connect_failed")])
        #expect(harness.bases.value.isEmpty)
        #expect(harness.unsupportedModes.value.isEmpty)
    }

    @Test func anUnsupportedModeClosesCleanlyAndIsReported() async throws {
        let harness = Harness()
        harness.result.setValue(.failure(UnsupportedSocketModeError(mode: "polling")))
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])

        try await waitUntil("finished") { events.isFinished }
        #expect(events.values == [.error("Unsupported socket mode: polling"), .close(1000, "unsupported_socket_mode")])
        #expect(harness.unsupportedModes.value == ["polling"])
        #expect(harness.bases.value.isEmpty)

        await transport.disconnect(code: 1000, reason: nil)
        #expect(events.values.count == 2)
    }

    @Test func aHandshakeFailureInvalidatesTheUrl() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        await harness.base?.emit(.error("handshake failed"))
        await harness.base?.end()

        try await waitUntil("finished") { events.isFinished }
        #expect(harness.invalidations.value == 1)
    }

    @Test func aCloseBeforeOpenInvalidatesTheUrl() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        await transport.connect(with: [:])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        await harness.base?.emit(.close(1006, nil))
        try await waitUntil("invalidated") { harness.invalidations.value == 1 }
    }

    @Test func aCloseAfterOpenDoesNotInvalidateTheUrl() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        await harness.base?.emit(.open)
        await harness.base?.emit(.close(1006, nil))
        try await waitUntil("events") { events.values.count == 2 }
        #expect(harness.invalidations.value == 0)
    }

    @Test func aRequestedCloseBeforeOpenDoesNotInvalidateTheUrl() async throws {
        let harness = Harness()
        let transport = harness.makeTransport()
        let events = StreamRecorder(await transport.events(bufferingPolicy: .unbounded))
        await transport.connect(with: [:])
        try await waitUntil("base connect") { await harness.base?.connectHeaders.count == 1 }

        await transport.disconnect(code: 1000, reason: nil)
        try await waitUntil("finished") { events.isFinished }
        #expect(harness.invalidations.value == 0)
    }
}
