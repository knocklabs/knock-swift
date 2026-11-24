//
//  SocketGatewayTransport.swift
//
//
//  Created by Knock on 11/23/26.
//

import Foundation
internal import PhoenixNectar

/// A `PhoenixTransport` that asks the socket gateway for a signed URL, then opens the websocket through a base transport.
///
/// PhoenixNectar creates a transport for every connect and reconnect, so every connection gets a fresh gateway lookup
/// (or a cached one). The query PhoenixNectar built for the endpoint (`vsn`, `api_key`, `user_token`) is appended to
/// the signed URL.
internal actor SocketGatewayTransport: PhoenixTransport {
    typealias BaseTransportFactory = @Sendable (URL) -> any PhoenixTransport

    private let unsignedQuery: String?
    private let baseTransport: BaseTransportFactory
    private let fetchConnectUrl: @Sendable () async throws -> SocketGatewayConnection
    private let onConnectUrlInvalid: @Sendable () async -> Void
    private let onUnsupportedMode: @Sendable (String?) async -> Void

    private var inner: (any PhoenixTransport)?
    private var fetchTask: Task<Void, Never>?
    private var forwardTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<TransportEvent>.Continuation] = [:]
    private var started = false
    /// Set once a terminal event was produced by this transport itself (not by the inner transport).
    private var settled = false
    private var opened = false
    private var closeRequested = false
    private var reportedInvalidUrl = false

    init(
        url: URL,
        baseTransport: @escaping BaseTransportFactory = { URLSessionTransport(url: $0) },
        fetchConnectUrl: @escaping @Sendable () async throws -> SocketGatewayConnection,
        onConnectUrlInvalid: @escaping @Sendable () async -> Void = {},
        onUnsupportedMode: @escaping @Sendable (String?) async -> Void = { _ in }
    ) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        self.unsignedQuery = (query?.isEmpty == false) ? query : nil
        self.baseTransport = baseTransport
        self.fetchConnectUrl = fetchConnectUrl
        self.onConnectUrlInvalid = onConnectUrlInvalid
        self.onUnsupportedMode = onUnsupportedMode
    }

    func readyState() async -> PhoenixTransportReadyState {
        if let inner {
            return await inner.readyState()
        }
        return started && !settled ? .connecting : .closed
    }

    func events(bufferingPolicy: AsyncStream<TransportEvent>.Continuation.BufferingPolicy) async -> AsyncStream<TransportEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<TransportEvent>.makeStream(bufferingPolicy: bufferingPolicy)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    func connect(with headers: [String: String]) async {
        guard !started, !settled else { return }
        started = true
        // Returns right away so the socket is not held up by the gateway request.
        fetchTask = Task { [weak self] in
            await self?.start(headers: headers)
        }
    }

    func disconnect(code: Int, reason: String?) async {
        guard !settled, !closeRequested else { return }
        guard let inner else {
            fetchTask?.cancel()
            fetchTask = nil
            settled = true
            emit(.close(1000, reason))
            finish()
            return
        }
        closeRequested = true
        await inner.disconnect(code: code, reason: reason)
    }

    func sendText(data: Data) async {
        await inner?.sendText(data: data)
    }

    func sendBinary(data: Data) async {
        await inner?.sendBinary(data: data)
    }

    // MARK: Connecting

    private func start(headers: [String: String]) async {
        let connection: SocketGatewayConnection
        do {
            connection = try await fetchConnectUrl()
        } catch let error as UnsupportedSocketModeError {
            guard !settled else { return }
            // The handler disconnects the socket. Emits no error or close: PhoenixNectar would reconnect on either.
            await onUnsupportedMode(error.mode)
            if !settled {
                settled = true
                finish()
            }
            return
        } catch {
            guard !settled, !Task.isCancelled else { return }
            fail(error: error.localizedDescription, code: 1006, reason: "gateway_connect_failed")
            return
        }
        guard !settled, !Task.isCancelled else { return }

        guard let url = Self.url(signedUrl: connection.signedUrl, unsignedQuery: unsignedQuery) else {
            fail(error: "The gateway returned an invalid URL", code: 1006, reason: "gateway_connect_failed")
            return
        }

        let transport = baseTransport(url)
        inner = transport
        let events = await transport.events(bufferingPolicy: .unbounded)
        forwardTask = Task { [weak self] in
            for await event in events {
                await self?.forward(event)
            }
            await self?.finish()
        }
        guard !settled, !closeRequested else { return }
        await transport.connect(with: headers)
    }

    /// Appends without deduplicating, as the signed URL does not contain the client's parameters.
    static func url(signedUrl: String, unsignedQuery: String?) -> URL? {
        guard let unsignedQuery else { return URL(string: signedUrl) }
        let separator = signedUrl.contains("?") ? "&" : "?"
        return URL(string: signedUrl + separator + unsignedQuery)
    }

    private func forward(_ event: TransportEvent) async {
        switch event {
        case .open:
            opened = true
        case .error, .close:
            if !opened, !closeRequested, !reportedInvalidUrl {
                reportedInvalidUrl = true
                await onConnectUrlInvalid()
            }
        case .message, .messageData:
            break
        }
        emit(event)
    }

    /// Ends the connection attempt with an error and a close, once.
    private func fail(error: String, code: Int, reason: String) {
        guard !settled else { return }
        settled = true
        emit(.error(error))
        emit(.close(code, reason))
        finish()
    }

    private func emit(_ event: TransportEvent) {
        continuations.values.forEach { $0.yield(event) }
    }

    private func finish() {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
