import Foundation
import XCTest
import SwiftPhoenixClient
@testable import Knock

/// Mirrors `URLSessionTransport`'s threading model: state is guarded by a serial queue, while
/// delegate callbacks are delivered under a separate recursive delivery lock that the `delegate`
/// setter also takes. Reproducing that split matters — it is what makes a lock-ordering bug
/// between the delivery lock and `FeedModule.lifecycleQueue` observable in these tests.
final class FakeFeedTransport: PhoenixTransport {
    private let eventQueue = DispatchQueue(label: "com.knock.tests.transport.events")
    private let eventQueueKey = DispatchSpecificKey<Void>()
    private let deliveryLock = NSRecursiveLock()
    private var _readyState: PhoenixTransportReadyState = .closed
    private var _delegate: PhoenixTransportDelegate?
    private var _connectCount = 0
    private var _disconnectCount = 0
    
    init() {
        eventQueue.setSpecific(key: eventQueueKey, value: ())
    }
    
    private func syncOnEventQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: eventQueueKey) != nil {
            return work()
        }
        return eventQueue.sync(execute: work)
    }
    
    private func deliver(_ body: (PhoenixTransportDelegate) -> Void) {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard let delegate = syncOnEventQueue({ _delegate }) else { return }
        body(delegate)
    }
    
    var readyState: PhoenixTransportReadyState {
        get { syncOnEventQueue { _readyState } }
        set { syncOnEventQueue { _readyState = newValue } }
    }
    
    var delegate: PhoenixTransportDelegate? {
        get { syncOnEventQueue { _delegate } }
        set {
            deliveryLock.lock()
            defer { deliveryLock.unlock() }
            syncOnEventQueue { _delegate = newValue }
        }
    }
    
    var connectCount: Int { syncOnEventQueue { _connectCount } }
    
    var disconnectCount: Int { syncOnEventQueue { _disconnectCount } }
    
    func connect(with headers: [String : Any]) {
        syncOnEventQueue {
            _connectCount += 1
            _readyState = .open
        }
        deliver { $0.onOpen(response: nil) }
    }
    
    func disconnect(code: Int, reason: String?) {
        syncOnEventQueue {
            _disconnectCount += 1
            _readyState = .closed
        }
        deliver { $0.onClose(code: code, reason: reason) }
    }
    
    func send(data: Data) {
        syncOnEventQueue { }
    }
    
    func fail(_ error: Error, response: URLResponse? = nil) {
        syncOnEventQueue { _readyState = .closed }
        deliver { $0.onError(error: error, response: response) }
    }
}

final class FeedLifecycleTests: XCTestCase {
    private func makeModule(transport: FakeFeedTransport) -> FeedModule {
        let socket = Socket(endPoint: "ws://localhost:1/socket", transport: { _ in transport })
        socket.skipHeartbeat = true
        return FeedModule(
            socket: socket,
            feedId: "feed-id",
            userId: "user-id",
            options: Knock.FeedClientOptions(archived: .exclude)
        )
    }
    
    func testConnectIsIdempotent() {
        let transport = FakeFeedTransport()
        let module = makeModule(transport: transport)
        
        module.connectToFeed()
        module.connectToFeed()
        module.connectToFeed()
        
        XCTAssertEqual(module.test_channelCount, 1)
        XCTAssertEqual(transport.connectCount, 1)
        XCTAssertTrue(module.test_isFeedConnected)
        XCTAssertTrue(module.test_hasFeedChannel)
    }
    
    func testDisconnectClearsChannelAndAllowsReconnect() {
        let transport = FakeFeedTransport()
        let module = makeModule(transport: transport)
        
        module.connectToFeed()
        module.disconnectFromFeed()
        
        XCTAssertFalse(module.test_isFeedConnected)
        XCTAssertFalse(module.test_hasFeedChannel)
        XCTAssertEqual(module.test_channelCount, 0)
        XCTAssertEqual(transport.disconnectCount, 1)
        
        module.connectToFeed()
        
        XCTAssertEqual(module.test_channelCount, 1)
        XCTAssertEqual(transport.connectCount, 2)
        XCTAssertTrue(module.test_hasFeedChannel)
    }
    
    func testBackgroundForegroundNetworkLossCycleDoesNotAccumulateChannels() {
        let transport = FakeFeedTransport()
        let module = makeModule(transport: transport)
        
        for _ in 0..<20 {
            module.connectToFeed()
            XCTAssertEqual(module.test_channelCount, 1)
            
            transport.fail(URLError(.networkConnectionLost))
            
            module.disconnectFromFeed()
            XCTAssertFalse(module.test_hasFeedChannel)
            XCTAssertEqual(module.test_channelCount, 0)
        }
        
        module.connectToFeed()
        
        XCTAssertEqual(module.test_channelCount, 1)
        XCTAssertEqual(transport.connectCount, 21)
    }
    
    func testHttpErrorDuringConnectDisconnectsWithoutDeadlock() {
        let transport = FakeFeedTransport()
        let module = makeModule(transport: transport)
        module.connectToFeed()
        
        let response = HTTPURLResponse(
            url: URL(string: "https://api.knock.app/ws")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        transport.fail(URLError(.userAuthenticationRequired), response: response)
        
        XCTAssertFalse(module.test_isFeedConnected)
        XCTAssertFalse(module.test_hasFeedChannel)
    }
    
    /// `connectToFeed` holds the lifecycle queue while calling into the socket, which acquires
    /// the transport's delivery lock. A socket error is delivered in the opposite direction,
    /// with that lock already held. If the error handler took the lifecycle queue synchronously
    /// rather than hopping onto it, these two orderings would deadlock.
    func testSocketErrorDuringConnectDoesNotDeadlockAgainstTransportQueue() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.knock.app/ws")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        
        for _ in 0..<200 {
            let transport = FakeFeedTransport()
            let module = makeModule(transport: transport)
            let finished = DispatchGroup()
            
            finished.enter()
            DispatchQueue.global().async {
                module.connectToFeed()
                finished.leave()
            }
            finished.enter()
            DispatchQueue.global().async {
                transport.fail(URLError(.userAuthenticationRequired), response: response)
                finished.leave()
            }
            
            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success,
                           "connectToFeed and socket error delivery deadlocked")
            module.disconnectFromFeed()
        }
    }
    
    func testConcurrentConnectDisconnectAndTransportFailure() {
        let transport = FakeFeedTransport()
        let module = makeModule(transport: transport)
        let group = DispatchGroup()
        
        for _ in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                module.connectToFeed()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                transport.fail(URLError(.networkConnectionLost))
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                module.disconnectFromFeed()
                group.leave()
            }
        }
        
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        module.disconnectFromFeed()
        XCTAssertFalse(module.test_hasFeedChannel)
        XCTAssertFalse(module.test_isFeedConnected)
        // The state above can be reached while the socket is still open if a connect and a
        // disconnect interleave, which would leak a live socket after backgrounding.
        XCTAssertEqual(transport.readyState, .closed)
    }
    
    func testDeinitDisconnectsAndReleasesModule() {
        let transport = FakeFeedTransport()
        weak var weakModule: FeedModule?
        
        autoreleasepool {
            let module = makeModule(transport: transport)
            weakModule = module
            module.connectToFeed()
            XCTAssertTrue(module.test_isFeedConnected)
        }
        
        XCTAssertNil(weakModule)
        XCTAssertGreaterThanOrEqual(transport.disconnectCount, 1)
    }
}
