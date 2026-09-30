//
//  InAppFeedViewModelTests.swift
///
//
//  Created by Matt Gardner on 5/25/24.
//

import Foundation
import XCTest
@testable import Knock

@MainActor
final class InAppFeedViewModelTests: XCTestCase {
    private func makeViewModel(
        feedClientOptions: Knock.FeedClientOptions = .init(),
        currentFilter: Knock.InAppFeedFilter? = nil
    ) -> Knock.InAppFeedViewModel {
        Knock.InAppFeedViewModel(
            feedClientOptions: feedClientOptions,
            currentFilter: currentFilter,
            filterOptions: nil,
            topButtonActions: nil,
            feedManagerProvider: { nil }
        )
    }
    
    func generateTestFeedItem(status: Knock.FeedItemScope, id: String = "", cursor: String = "") -> Knock.FeedItem {
        var item = Knock.FeedItem(__cursor: cursor, actors: [], activities: [], blocks: [], data: [:], id: id, inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
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
    
    func testOptimisticMarkItemAsRead() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .read)
        viewModel.feed.entries = [item]
        viewModel.feed.meta.unreadCount = 1
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .read)
        XCTAssertTrue(viewModel.feed.entries.first!.read_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
    
    func testOptimisticMarkItemAsReadWithUnreadFilter() {
        let viewModel = makeViewModel()
        viewModel.feedClientOptions.status = .unread
        let item = generateTestFeedItem(status: .read)
        viewModel.feed.entries = [item]
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .read)
        // This should remove the item from the feed since we currently have the unread filter selected
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticMarkItemAsSeen() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .seen)
        viewModel.feed.entries = [item]
        viewModel.feed.meta.unseenCount = 1
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.first!.seen_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unseenCount == 0)
    }
    
    func testOptimisticMarkItemAsReadWithUnseenFilter() {
        let viewModel = makeViewModel()
        viewModel.feedClientOptions.status = .unseen
        let item = generateTestFeedItem(status: .seen)
        viewModel.feed.entries = [item]
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticMarkItemAsArchived() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .archived)
        viewModel.feed.entries = [item]
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .seen)
        XCTAssertTrue(viewModel.feed.entries.first!.archived_at != nil)
    }
    
    func testOptimisticMarkItemAsArchivedWithNoArchivedFilter() {
        let viewModel = makeViewModel()
        viewModel.feedClientOptions.status = .all
        viewModel.feedClientOptions.archived = .exclude
        let item = generateTestFeedItem(status: .archived)
        viewModel.feed.entries = [item]
        viewModel.optimisticallyUpdateStatusForItem(item: item, status: .archived)
        XCTAssertTrue(viewModel.feed.entries.isEmpty)
    }
    
    func testOptimisticUpdateIgnoresUnknownItem() {
        let viewModel = makeViewModel()
        viewModel.feed.entries = [generateTestFeedItem(status: .unread, id: "a")]
        viewModel.feed.meta.unreadCount = 1
        viewModel.optimisticallyUpdateStatusForItem(item: generateTestFeedItem(status: .unread, id: "b"), status: .read)
        XCTAssertNil(viewModel.feed.entries.first?.read_at)
        XCTAssertEqual(viewModel.feed.meta.unreadCount, 1)
    }
    
    func testOptimisticBulkMarkItemsAsRead() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .unread)
        let item2 = generateTestFeedItem(status: .seen)
        let item3 = generateTestFeedItem(status: .unread)
        let item4 = generateTestFeedItem(status: .read)

        viewModel.feed.entries = [item, item2, item3, item4]
        viewModel.feed.meta.unreadCount = 3
        viewModel.optimisticallyBulkUpdateStatus(updatedStatus: .read)
        XCTAssertTrue(viewModel.feed.entries.first!.read_at != nil)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
    
    func testOptimisticBulkMarkItemAsArchived() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .unread)
        let item2 = generateTestFeedItem(status: .seen)
        let item3 = generateTestFeedItem(status: .unread)
        let item4 = generateTestFeedItem(status: .read)

        viewModel.feed.entries = [item, item2, item3, item4]
        viewModel.optimisticallyBulkUpdateStatus(updatedStatus: .archived)
        XCTAssertTrue(viewModel.feed.entries.count == 0)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
    
    func testOptimisticBulkMarkItemAsArchivedAndShouldHideArchived() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .unread)
        let item2 = generateTestFeedItem(status: .seen)
        let item3 = generateTestFeedItem(status: .unread)
        let item4 = generateTestFeedItem(status: .read)

        viewModel.feed.entries = [item, item2, item3, item4]
        viewModel.feedClientOptions.archived = .exclude
        viewModel.optimisticallyBulkUpdateStatus(updatedStatus: .archived)
        XCTAssertTrue(viewModel.feed.entries.count == 0)
        XCTAssertTrue(viewModel.feed.meta.unreadCount == 0)
    }
    
    func testOptimisticBulkMarkItemAsArchivedWithUnReadScope() {
        let viewModel = makeViewModel()
        let item = generateTestFeedItem(status: .unread)
        let item2 = generateTestFeedItem(status: .unread)
        let item3 = generateTestFeedItem(status: .unread)
        let item4 = generateTestFeedItem(status: .read)

        viewModel.feed.entries = [item, item2, item3, item4]
        viewModel.optimisticallyBulkUpdateStatus(updatedStatus: .archived, archivedScope: .unread)
        XCTAssertTrue(viewModel.feed.entries.count == 1)
    }
    
    // MARK: Request options
    
    func testInitialFilterSetsStatus() {
        let viewModel = makeViewModel(currentFilter: .init(scope: .unread))
        XCTAssertEqual(viewModel.feedClientOptions.status, .unread)
        XCTAssertEqual(viewModel.requestOptions().status, .unread)
    }
    
    func testRequestOptionsMapArchivedFilterToArchivedOnly() {
        let viewModel = makeViewModel(feedClientOptions: .init(tenant: "acme", archived: .exclude), currentFilter: .init(scope: .archived))
        let options = viewModel.requestOptions()
        XCTAssertEqual(options.status, .all)
        XCTAssertEqual(options.archived, .only)
        XCTAssertEqual(options.tenant, "acme")
        XCTAssertEqual(viewModel.feedClientOptions.status, .archived, "Building request options must not change the stored options")
        XCTAssertEqual(viewModel.feedClientOptions.archived, .exclude)
    }
    
    func testRequestOptionsKeepConfiguredArchivedScopeForOtherFilters() {
        let viewModel = makeViewModel(feedClientOptions: .init(archived: .include))
        let options = viewModel.requestOptions()
        XCTAssertEqual(options.status, .all)
        XCTAssertEqual(options.archived, .include)
    }
    
    func testRequestOptionsOnlyCarryTheRequestedCursor() {
        let viewModel = makeViewModel(feedClientOptions: .init(before: "stale-before", after: "stale-after"))
        
        let refresh = viewModel.requestOptions()
        XCTAssertNil(refresh.before)
        XCTAssertNil(refresh.after)
        
        let newer = viewModel.requestOptions(before: "cursor-1")
        XCTAssertEqual(newer.before, "cursor-1")
        XCTAssertNil(newer.after)
        
        let nextPage = viewModel.requestOptions(after: "cursor-2")
        XCTAssertNil(nextPage.before)
        XCTAssertEqual(nextPage.after, "cursor-2")
    }
    
    // MARK: Merging
    
    func testNewMessagesArePrependedAndMoveTheBeforeCursor() {
        let viewModel = makeViewModel()
        viewModel.feed.entries = [generateTestFeedItem(status: .unread, id: "old", cursor: "c-old")]
        viewModel.feed.pageInfo.before = "c-old"
        
        let incoming = Knock.Feed(
            entries: [generateTestFeedItem(status: .unread, id: "new", cursor: "c-new")],
            meta: .init(totalCount: 2, unreadCount: 2, unseenCount: 2)
        )
        viewModel.mergeFeedsForNewMessageReceived(feed: incoming)
        
        XCTAssertEqual(viewModel.feed.entries.map(\.id), ["new", "old"])
        XCTAssertEqual(viewModel.feed.pageInfo.before, "c-new")
        XCTAssertEqual(viewModel.feed.meta.unreadCount, 2)
    }
    
    func testNewMessagesSkipEntriesAlreadyInTheFeed() {
        let viewModel = makeViewModel()
        viewModel.feed.entries = [generateTestFeedItem(status: .unread, id: "a", cursor: "c-a")]
        
        let incoming = Knock.Feed(entries: [
            generateTestFeedItem(status: .unread, id: "b", cursor: "c-b"),
            generateTestFeedItem(status: .unread, id: "a", cursor: "c-a"),
        ])
        viewModel.mergeFeedsForNewMessageReceived(feed: incoming)
        
        XCTAssertEqual(viewModel.feed.entries.map(\.id), ["b", "a"])
    }
    
    func testEmptyNewMessageResponseKeepsTheBeforeCursor() {
        let viewModel = makeViewModel()
        viewModel.feed.pageInfo.before = "c-old"
        viewModel.mergeFeedsForNewMessageReceived(feed: Knock.Feed(meta: .init(unreadCount: 4)))
        XCTAssertEqual(viewModel.feed.pageInfo.before, "c-old")
        XCTAssertEqual(viewModel.feed.meta.unreadCount, 4)
    }
    
    func testNewPageIsAppendedWithoutDuplicates() {
        let viewModel = makeViewModel()
        viewModel.feed.entries = [generateTestFeedItem(status: .unread, id: "a")]
        viewModel.feed.pageInfo.after = "page-1"
        
        let page = Knock.Feed(
            entries: [generateTestFeedItem(status: .unread, id: "a"), generateTestFeedItem(status: .unread, id: "b")],
            pageInfo: .init(after: nil)
        )
        viewModel.mergeFeedsForNewPageOfFeed(feed: page)
        
        XCTAssertEqual(viewModel.feed.entries.map(\.id), ["a", "b"])
        XCTAssertNil(viewModel.feed.pageInfo.after)
        XCTAssertFalse(viewModel.isMoreContentAvailable())
    }
    
    // MARK: Without a feed manager
    
    func testConnectingWithoutAFeedManagerDoesNothing() async {
        let viewModel = makeViewModel()
        viewModel.feed.entries = [generateTestFeedItem(status: .unread, id: "a")]
        await viewModel.connectFeedAndObserveNewMessages()
        await viewModel.refreshFeed(showRefreshIndicator: true)
        await viewModel.fetchNewPageOfFeedItems()
        XCTAssertEqual(viewModel.feed.entries.map(\.id), ["a"])
        XCTAssertFalse(viewModel.showRefreshIndicator)
    }
    
    func testViewModelIsReleasedWhileObservingNewMessages() async throws {
        let environment = KnockEnvironment()
        let factory = FakeRealtimeSocketFactory()
        let feedManager = Knock.FeedManager(
            feedModule: FeedModule(feedId: "feed", options: .init(), environment: { environment }, socketFactory: factory.make, realtimePolicy: .fast),
            lifecycleEvents: AsyncStream { _ in }
        )
        weak var weakViewModel: Knock.InAppFeedViewModel?
        do {
            let viewModel = Knock.InAppFeedViewModel(
                feedClientOptions: .init(),
                currentFilter: nil,
                filterOptions: nil,
                topButtonActions: nil,
                feedManagerProvider: { feedManager }
            )
            weakViewModel = viewModel
            await viewModel.connectFeedAndObserveNewMessages()
            try await waitUntil { await feedManager.feedModule.realtime.subscriberCount == 1 }
        }
        XCTAssertNil(weakViewModel)
        try await waitUntil { await feedManager.feedModule.realtime.subscriberCount == 0 }
    }
}
