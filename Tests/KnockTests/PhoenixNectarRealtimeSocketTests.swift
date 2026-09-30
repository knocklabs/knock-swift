//
//  PhoenixNectarRealtimeSocketTests.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
import PhoenixNectar
import Testing
@testable import Knock

@Suite("PhoenixNectarRealtimeSocket")
struct PhoenixNectarRealtimeSocketTests {
    typealias Frame = ChannelSignalClassifier.Frame

    static func reply(ref: String, joinRef: String, status: PushStatus) -> Frame {
        Frame(topic: "feeds:1", event: .system(.reply), ref: ref, joinRef: joinRef, status: status)
    }

    static func frame(_ event: PhoenixSystemEvent, joinRef: String?) -> Frame {
        Frame(topic: "feeds:1", event: .system(event), ref: nil, joinRef: joinRef, status: nil)
    }

    @Test func channelFramesMapToSignals() {
        var classifier = ChannelSignalClassifier()
        classifier.joinSent(topic: "feeds:1", ref: "2")

        #expect(classifier.signal(for: Self.reply(ref: "2", joinRef: "1", status: .ok)) { "" } == .rejoined)
        #expect(classifier.signal(for: Self.frame(.error, joinRef: "1")) { "" } == .errored)
        #expect(classifier.signal(for: Self.frame(.close, joinRef: "1")) { "" } == .closed)

        classifier.joinSent(topic: "feeds:1", ref: "4")
        #expect(classifier.signal(for: Self.reply(ref: "4", joinRef: "3", status: .error)) { "token expired" } == .rejoinRejected(reason: "token expired"))
    }

    @Test func otherFramesAreNotSignals() {
        var classifier = ChannelSignalClassifier()
        let reason: () -> String = {
            Issue.record("The reason is only read for rejected replies")
            return ""
        }
        #expect(classifier.signal(for: Self.reply(ref: "2", joinRef: "1", status: .timeout), reason: reason) == nil)
        #expect(classifier.signal(for: Frame(topic: "feeds:1", event: .system(.reply), ref: nil, joinRef: nil, status: .ok), reason: reason) == nil)
        #expect(classifier.signal(for: Self.frame(.heartbeat, joinRef: nil), reason: reason) == nil)
        #expect(classifier.signal(for: Frame(topic: "feeds:1", event: .named("new-message"), ref: nil, joinRef: "1", status: nil), reason: reason) == nil)
    }

    @Test func repliesToEarlierJoinsAreIgnored() {
        var classifier = ChannelSignalClassifier()
        classifier.joinSent(topic: "feeds:1", ref: "2")
        classifier.joinSent(topic: "feeds:1", ref: "4")

        #expect(classifier.signal(for: Self.reply(ref: "2", joinRef: "1", status: .error)) { "stale" } == nil)
        #expect(classifier.signal(for: Self.reply(ref: "2", joinRef: "1", status: .ok)) { "" } == nil)
        #expect(classifier.signal(for: Self.reply(ref: "4", joinRef: "3", status: .ok)) { "" } == .rejoined)
    }

    @Test func aReplyThatArrivesBeforeItsJoinIsReportedCounts() {
        var classifier = ChannelSignalClassifier()
        classifier.joinSent(topic: "feeds:1", ref: "2")

        #expect(classifier.signal(for: Self.reply(ref: "6", joinRef: "5", status: .ok)) { "" } == .rejoined)
        classifier.joinSent(topic: "feeds:1", ref: "6")
        #expect(classifier.signal(for: Self.reply(ref: "2", joinRef: "1", status: .ok)) { "" } == nil)
    }

    @Test func errorsAndClosesFromEarlierJoinsAreIgnored() {
        var classifier = ChannelSignalClassifier()
        classifier.joinSent(topic: "feeds:1", ref: "4")
        #expect(classifier.signal(for: Self.reply(ref: "4", joinRef: "3", status: .ok)) { "" } == .rejoined)

        #expect(classifier.signal(for: Self.frame(.close, joinRef: "1")) { "" } == nil)
        #expect(classifier.signal(for: Self.frame(.error, joinRef: "1")) { "" } == nil)
        #expect(classifier.signal(for: Self.frame(.close, joinRef: "3")) { "" } == .closed)
        #expect(classifier.signal(for: Self.frame(.error, joinRef: nil)) { "" } == .errored)
    }

    @Test func topicsAreTrackedSeparately() {
        var classifier = ChannelSignalClassifier()
        classifier.joinSent(topic: "feeds:1", ref: "10")
        let other = Frame(topic: "feeds:2", event: .system(.reply), ref: "2", joinRef: "1", status: .ok)

        #expect(classifier.signal(for: other) { "" } == .rejoined)
    }

    @Test func transportJoinErrorsAreRetried() {
        let errors: [PhoenixError] = [.timeout, .notConnected, .channelClosed("feeds:1"), .bufferOverflow("full"), .protocolViolation("bad frame")]
        for error in errors {
            #expect(PhoenixNectarRealtimeSocket.joinError(from: error) == .transient(reason: error.localizedDescription))
        }
    }

    @Test func localJoinErrorsAreUnrecoverable() {
        let errors: [PhoenixError] = [.encodingFailure("params"), .decodingFailure("reply"), .malformedEndpoint("ws://")]
        for error in errors {
            #expect(PhoenixNectarRealtimeSocket.joinError(from: error) == .unrecoverable(reason: error.localizedDescription))
        }
    }

    @Test func rejectionReasonsAreReadFromTheReply() {
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: ["reason": "unauthorized"]) == "unauthorized")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: nil) == "unknown")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: [:]) == "unknown")
        #expect(PhoenixNectarRealtimeSocket.reason(fromResponse: ["code": 42]).contains("42"))
    }

    @Test func joinParametersThatCannotBeEncodedAreUnrecoverable() async throws {
        struct Params: Encodable, Sendable { let value = Double.nan }
        let socket = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { [:] })

        do {
            _ = try await socket.join(topic: "feeds:1", params: Params())
            Issue.record("Expected the join to fail")
        } catch let error as RealtimeJoinError {
            guard case .unrecoverable = error else {
                Issue.record("Expected an unrecoverable join error, got \(error)")
                return
            }
        }
    }

    @Test func theSocketValidatesItsEndpoint() throws {
        #expect(throws: PhoenixError.malformedEndpoint("")) {
            try PhoenixNectarRealtimeSocket(endpoint: "", connectParams: { [:] })
        }
        _ = try PhoenixNectarRealtimeSocket(endpoint: "wss://api.knock.app/ws/v1/websocket", connectParams: { ["api_key": "pk_test"] })
    }
}
