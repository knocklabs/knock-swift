//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/10/24.
//

import Foundation
import SwiftUI
import Combine

class KnockInAppFeedViewModel: ObservableObject {
    @Published var feed: Knock.Feed = Knock.Feed()
    @Published var tenantId: String?
    @Published var hasTenant: Bool?
    @Published var currentFilter: Knock.FeedItemScope = .all
    @Published var filterOptions: [Knock.FeedItemScope] = [.all, .unread, .read]
    @Published var defaultMessageStatusUpdate: Knock.BulkChannelMessageStatusUpdateType = .read
    
    let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>()
    let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>()

    var feedClientOptions: Knock.FeedClientOptions
    private var _feedClientOptions: Knock.FeedClientOptions
    
    init(feedClientOptions: Knock.FeedClientOptions = .init(), tenantId: String? = nil, hasTenant: Bool? = nil) {
        self.feedClientOptions = feedClientOptions
        self._feedClientOptions = feedClientOptions

        self.tenantId = tenantId ?? feedClientOptions.tenant
        self.hasTenant = hasTenant ?? feedClientOptions.has_tenant
        self.currentFilter = feedClientOptions.status ?? .all

        self.feedClientOptions.status = self.currentFilter
        self.feedClientOptions.tenant = self.tenantId
        self.feedClientOptions.has_tenant = self.hasTenant
        self._feedClientOptions = self.feedClientOptions
    }
    
    func refreshFeed() async {
        do {
            self.feedClientOptions.tenant = tenantId
            self._feedClientOptions = feedClientOptions
            guard let userFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
            await MainActor.run {
                self.feed = userFeed
                self.feed.page_info.before = feed.entries.first?.__cursor
            }
        } catch {
            Knock.shared.log(type: .error, category: .feed, message: "error in refreshFeed: \(error.localizedDescription)")
        }
    }

    func initializeFeed() async {
        await refreshFeed()
        Knock.shared.feedManager?.connectToFeed()
        Knock.shared.feedManager?.on(eventName: "new-message") { [weak self] _ in
            guard let self = self else { return }
            _feedClientOptions.before = self.feed.page_info.before
            Knock.shared.feedManager?.getUserFeedContent(options: _feedClientOptions) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let feed):
                        self.mergeFeeds(feed: feed)
                    case .failure(let error):
                        Knock.shared.log(type: .error, category: .feed, message: "error in getUserFeedContent: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func archiveItem(_ item: Knock.FeedItem) async {
        do {
            let message = try await Knock.shared.updateMessageStatus(messageId: item.id, status: .archive)
            
            // remove local message if update was successful
            await MainActor.run {
                feed.entries = feed.entries.filter{ $0.id != message.id }
            }
            
            // make a request to get the latest feed metadata
            let options = Knock.FeedClientOptions(tenant: tenantId, has_tenant: true)
            if let feed = try await Knock.shared.feedManager?.getUserFeedContent(options: options) {
                await MainActor.run {
                    self.feed.meta = feed.meta
                }
            }
        } catch {
            Knock.shared.log(type: .error, category: .feed, message: "error in archiveItem(): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func markAllAsSeen() async {
        if feed.meta.unseen_count > 0 {
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: tenantId, has_tenant: true, archived: nil)
            do {
                let _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: defaultMessageStatusUpdate, options: feedOptions)

                await MainActor.run {
                    feed.meta.unseen_count = 0
                    let seenDate = Date()
                    feed.entries = feed.entries.map { item in
                        var newItem = item
                        newItem.seen_at = seenDate
                        return newItem
                    }
                }
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in makeBulkStatusUpdate: \(error.localizedDescription)")
            }
        }
    }
    
    func feedItemButtonTapped(item: Knock.FeedItem, actionString: String) {
        didTapFeedItemButtonPublisher.send(actionString)
    }
    
    func feedItemRowTapped(item: Knock.FeedItem) {
        didTapFeedItemRowPublisher.send(item)
    }
    
    func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction) {
        switch swipeAction {
        case .archive:
            Task {
                await archiveItem(item)
            }
        case .markAsRead:
            break
        case .markAsSeen:
            break
        }
    }
    
    private func mergeFeeds(feed: Knock.Feed) {
        self.feed.entries.insert(contentsOf: feed.entries, at: 0)
        self.feed.meta = feed.meta
        self.feed.page_info.before = feed.entries.first?.__cursor
    }
}
