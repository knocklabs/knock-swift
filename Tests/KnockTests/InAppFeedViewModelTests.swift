//
//  InAppFeedViewModelTests.swift
///
//
//  Created by Matt Gardner on 5/25/24.
//

import Foundation
import XCTest
@testable import Knock

final class InAppFeedViewModelTests: XCTestCase {
    var viewModel: Knock.InAppFeedViewModel!
    var feedManager: Knock.FeedManager!
    
    override func setUp() {
        super.setUp()
        feedManager = try! Knock.FeedManager(feedId: "")
        Knock.shared.feedManager = feedManager
        viewModel = Knock.InAppFeedViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        feedManager = nil
        super.tearDown()
    }
    
    func generateTestFeedItem(status: Knock.FeedItemScope) -> Knock.FeedItem {
        var item = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [], data: [:], id: "", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        switch status {
        case .archived: item.archived_at = Date()
        case .unarchived: item.archived_at = nil
        case .interacted: 
            item.interacted_at = Date()
            item.read_at = Date()
        case .unread: item.read_at = nil
        case .read: item.read_at = Date()
        case .unseen: item.seen_at = nil
        case .seen: item.seen_at = Date()
        default: break
        }
        return item
    }
    
    func testOptimisticMarkItemAsRead() async {
        let item = generateTestFeedItem(status: .read)
        viewModel.feed.entries = [item]
        viewModel.feed.meta.unreadCount = 1
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .read)
        XCTAssertTrue(viewModel.feed.entries.first!.read_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
    
    func testOptimisticMarkItemAsReadWithUnreadFilter() async {
        viewModel.feedClientOptions.status = .unread
        let item = generateTestFeedItem(status: .read)
        viewModel.feed.entries = [item]
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .read)
        // This should remove the item from the feed since we currently have the unread filter selected
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticMarkItemAsSeen() async {
        let item = generateTestFeedItem(status: .seen)
        viewModel.feed.entries = [item]
        viewModel.feed.meta.unseenCount = 1
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.first!.seen_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unseenCount == 0)
    }
    
    func testOptimisticMarkItemAsReadWithUnseenFilter() async {
        viewModel.feedClientOptions.status = .unseen
        let item = generateTestFeedItem(status: .seen)
        viewModel.feed.entries = [item]
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticMarkItemAsArchived() async {
        let item = generateTestFeedItem(status: .archived)
        viewModel.feed.entries = [item]
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.first!.archived_at != nil)
    }
    
    func testOptimisticMarkItemAsArchivedWithNoArchivedFilter() async {
        viewModel.feedClientOptions.status = .all
        viewModel.feedClientOptions.archived = .exclude
        let item = generateTestFeedItem(status: .archived)
        viewModel.feed.entries = [item]
        await viewModel.optimisticallyUpdateStatusForItem(item: item, status: .archived)
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticBulkMarkItemAsRead() async {
        let item = generateTestFeedItem(status: .unread)
        let item2 = generateTestFeedItem(status: .seen)
        let item3 = generateTestFeedItem(status: .unread)
        let item4 = generateTestFeedItem(status: .read)

        viewModel.feed.entries = [item, item2, item3, item4]
        viewModel.feed.meta.unreadCount = 3
        await viewModel.optimisticallyBulkUpdateStatus(status: .read)
        XCTAssertTrue(viewModel.feed.entries.first!.read_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
}

//class MockFeedManager: FeedManagerProtocol { // Conform to the actual protocol used by Knock.FeedManager
//    var connectedToFeed = false
//    var messages = PassthroughSubject<Void, Never>()
//    
//    func connectToFeed() {
//        connectedToFeed = true
//    }
//    
//    func on(eventName: String, handler: @escaping (Any) -> Void) {
//        messages.sink(receiveValue: { _ in handler(()) }).store(in: &cancellables)
//    }
//    
//    func getUserFeedContent(options: Knock.FeedClientOptions, completion: @escaping (Result<Knock.Feed, Error>) -> Void) {
//        // Simulate API response
//        let feed = Knock.Feed(entries: [Knock.FeedItem(id: "1", title: "Test")], pageInfo: Knock.PageInfo(before: nil, after: nil), meta: Knock.FeedMeta())
//        completion(.success(feed))
//    }
//    
//    func makeBulkStatusUpdate(type: Knock.KnockMessageStatusBatchUpdateType, options: Knock.FeedClientOptions) async throws {
//        // Simulate bulk update
//    }
//}
//
//protocol FeedManagerProtocol {
//    
//}

