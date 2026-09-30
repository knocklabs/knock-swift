//
//  ChannelSignalClassifier.swift
//
//
//  Created by Knock on 9/30/26.
//

import Foundation
internal import PhoenixNectar

/// Turns inbound channel frames into signals, ignoring frames that belong to an earlier join of the topic.
///
/// PhoenixNectar drops stale frames before delivering channel messages, but the metrics hook sees every frame. Refs are
/// increasing counters, so a frame is stale when its ref (for replies) or join ref (for errors and closes) is older than
/// the latest join the classifier knows about.
internal struct ChannelSignalClassifier: Sendable {
    struct Frame: Sendable {
        var topic: String
        var event: PhoenixEvent
        var ref: String?
        var joinRef: String?
        var status: PushStatus?
    }

    /// The newest ref of a join push, or of a reply to one, seen for each topic.
    private var newestJoinPushRefs: [String: UInt64] = [:]
    /// The join ref of the latest join the server accepted for each topic.
    private var acceptedJoinRefs: [String: UInt64] = [:]

    mutating func joinSent(topic: String, ref: String?) {
        guard let ref = ref.flatMap(UInt64.init) else { return }
        newestJoinPushRefs[topic] = max(ref, newestJoinPushRefs[topic] ?? 0)
    }

    /// The signal for `frame`, or `nil` if it isn't one or belongs to an earlier join.
    ///
    /// The feed channel never pushes, so every reply on its topic is a reply to a join.
    mutating func signal(for frame: Frame, reason: () -> String) -> RealtimeChannelSignal? {
        switch frame.event {
        case .system(.reply):
            // Replies can arrive before the join's send is reported, so only replies to older joins are stale.
            guard let ref = frame.ref.flatMap(UInt64.init), ref >= (newestJoinPushRefs[frame.topic] ?? 0) else { return nil }
            newestJoinPushRefs[frame.topic] = ref
            switch frame.status {
            case .ok:
                if let joinRef = frame.joinRef.flatMap(UInt64.init) {
                    acceptedJoinRefs[frame.topic] = joinRef
                }
                return .rejoined
            case .error:
                return .rejoinRejected(reason: reason())
            case .timeout, nil:
                return nil
            }
        case .system(.error):
            return isCurrent(frame) ? .errored : nil
        case .system(.close):
            return isCurrent(frame) ? .closed : nil
        default:
            return nil
        }
    }

    private func isCurrent(_ frame: Frame) -> Bool {
        guard let joinRef = frame.joinRef.flatMap(UInt64.init), let accepted = acceptedJoinRefs[frame.topic] else { return true }
        return joinRef >= accepted
    }
}
