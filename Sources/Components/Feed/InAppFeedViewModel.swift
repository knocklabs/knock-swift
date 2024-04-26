//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/10/24.
//

import Foundation
import SwiftUI
import Combine

extension Knock {
    public class InAppFeedViewModel: ObservableObject {
        @Published public var feed: Knock.Feed = Knock.Feed()
        @Published public var tenantId: String?
        @Published public var currentFilter: InAppFeedFilter
        
        public let hasTenant: Bool?
        public let filterOptions: [InAppFeedFilter]
        public let topButtonActions: [Knock.FeedTopActionButtonType]?
        
        public let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>()
        public let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>()
        
        public var feedClientOptions: Knock.FeedClientOptions
        /*
         Maintain another set of options so that when we change things within it,
         we still have reference to the original for when the user wants to refresh the view.
        */
        private var _feedClientOptions: Knock.FeedClientOptions = .init()
        
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: Initialization
        
        public init(
            feedClientOptions: Knock.FeedClientOptions = .init(),
            tenantId: String? = nil,
            hasTenant: Bool? = nil,
            currentFilter: InAppFeedFilter? = nil,
            filterOptions: [InAppFeedFilter]? = nil,
            topButtonActions: [Knock.FeedTopActionButtonType]? = [.markAllAsRead(), .archiveRead()]
        ) {
            self.feedClientOptions = feedClientOptions
            
            self.tenantId = tenantId ?? feedClientOptions.tenant
            self.hasTenant = hasTenant ?? feedClientOptions.has_tenant
            self.filterOptions = filterOptions ?? [.init(scope: .all), .init(scope: .unread), .init(scope: .archived)]
            self.currentFilter = filterOptions?.first ?? .init(scope: .all)
            self.topButtonActions = topButtonActions
            
            self.feedClientOptions.status = self.currentFilter.scope
            self.feedClientOptions.tenant = self.tenantId
            self.feedClientOptions.has_tenant = self.hasTenant
            self._feedClientOptions = self.feedClientOptions
            
            $currentFilter
                .sink { [weak self] _ in
                    self?.filterDidChange()
                }
                .store(in: &cancellables)
        }
        
        public func initializeFeed() async {
            await refreshFeed()
            Knock.shared.feedManager?.connectToFeed()
            Knock.shared.feedManager?.on(eventName: "new-message") { [weak self] _ in
                guard let self = self else { return }
                _feedClientOptions.before = self.feed.pageInfo.before
                Knock.shared.feedManager?.getUserFeedContent(options: _feedClientOptions) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let feed):
                            self.mergeFeedsForNewMessageReceived(feed: feed)
                        case .failure(let error):
                            Knock.shared.log(type: .error, category: .feed, message: "error in getUserFeedContent: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        public func refreshFeed() async {
            do {
                self.feedClientOptions.tenant = tenantId
                self._feedClientOptions = feedClientOptions
                guard let userFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
                await MainActor.run {
                    self.feed = userFeed
                    self.feed.pageInfo.before = feed.entries.first?.__cursor
                }
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in refreshFeed: \(error.localizedDescription)")
            }
        }
        
        public func fetchNewPageOfFeedItems() async {
            guard let after = self.feed.pageInfo.after else { return }
            _feedClientOptions.after = after
            Knock.shared.feedManager?.getUserFeedContent(options: _feedClientOptions) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let feed):
                        self.mergeFeedsForNewPageOfFeed(feed: feed)
                    case .failure(let error):
                        Knock.shared.log(type: .error, category: .feed, message: "error in getUserFeedContent: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        public func isMoreContentAvailable() -> Bool {
            return feed.pageInfo.after != nil
        }
        
        public func topActionButtonTapped(action: Knock.FeedTopActionButtonType) async {
            switch action {
            case .archiveAll(_):
                await archiveAll(scope: .all)
            case .archiveRead(_):
                await archiveAll(scope: .read)
            case .markAllAsRead(_):
                await markAllAsRead()
            }
        }
        
        // MARK: Message Update Methods
        
        public func archiveItem(_ item: Knock.FeedItem) async {
            do {
                let message = try await Knock.shared.updateMessageStatus(messageId: item.id, status: .archived)
                
                // remove local message if update was successful
                await MainActor.run {
                    feed.entries = feed.entries.filter{ $0.id != message.id }
                }
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in archiveItem: \(error.localizedDescription)")
            }
        }
        
        public func archiveAll(scope: Knock.FeedItemScope) async {
            let feedOptions = Knock.FeedClientOptions(status: scope, tenant: tenantId, has_tenant: false, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .archived, options: feedOptions)
                await refreshFeed()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in archiveAll: \(error.localizedDescription)")
            }
        }
        
        public func markAllAsRead() async {
            guard feed.meta.unreadCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: tenantId, has_tenant: false, archived: nil)
            do {
                let result = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .read, options: feedOptions)
                
                await MainActor.run {
                    feed.meta.unreadCount = 0
                    let date = Date()
                    feed.entries = feed.entries.map { item in
                        var newItem = item
                        if newItem.read_at == nil {
                            newItem.read_at = date
                        }
                        return newItem
                    }
                }
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in markAllAsRead: \(error.localizedDescription)")
            }
        }
        
        public func markAllAsSeen() async {
            guard feed.meta.unseenCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: tenantId, has_tenant: false, archived: nil)
            do {
                let result = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .seen, options: feedOptions)
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in markAllAsSeen: \(error.localizedDescription)")
            }
        }
        
        public func markAsRead(_ item: Knock.FeedItem) async {
            guard item.read_at == nil else { return }
            do {
                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .read)
                
                if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
                    await MainActor.run {
                        feed.entries[index].read_at = Date()
                    }
                }
                
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in markAsRead: \(error.localizedDescription)")
            }
        }
        
        public func markAsUnread(_ item: Knock.FeedItem) async {
            guard item.read_at != nil else { return }
            do {
                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .unread)
                
                if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
                    await MainActor.run {
                        feed.entries[index].read_at = nil
                    }
                }
                
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in markAsUnread: \(error.localizedDescription)")
            }
        }
        
        public func markAsInteracted(_ item: Knock.FeedItem) async {
            do {
                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .interacted)
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in markAsInteracted: \(error.localizedDescription)")
            }
        }
        
        // MARK: FeedItemRow Interactions
        public func feedItemButtonTapped(item: Knock.FeedItem, actionString: String) {
            didTapFeedItemButtonPublisher.send(actionString)
        }
        
        public func feedItemRowTapped(item: Knock.FeedItem) {
            didTapFeedItemRowPublisher.send(item)
            Task {
                await markAsInteracted(item)
            }
        }
        
        // MARK: Swipe Actions
        public func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction) {
            switch swipeAction {
            case .archive:
                Task {
                    await archiveItem(item)
                }
            case .markAsRead:
                Task {
                    await markAsRead(item)
                }
            case .markAsUnread:
                Task {
                    await markAsUnread(item)
                }
            }
        }
        
        // MARK: Private Methods
        
        private func filterDidChange() {
            Task { [weak self] in
                self?.feedClientOptions.status = self?.currentFilter.scope
                self?._feedClientOptions.status = self?.currentFilter.scope
                await self?.refreshFeed()
            }
        }
        
        private func fetchNewMetaData() async {
            do {
                let options = Knock.FeedClientOptions(tenant: tenantId, has_tenant: true)
                if let feed = try await Knock.shared.feedManager?.getUserFeedContent(options: options) {
                    await MainActor.run {
                        self.feed.meta = feed.meta
                    }
                }
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in makeBulkStatusUpdate: \(error.localizedDescription)")
            }
        }
        
        private func mergeFeedsForNewMessageReceived(feed: Knock.Feed) {
            self.feed.entries.insert(contentsOf: feed.entries, at: 0)
            self.feed.meta = feed.meta
            self.feed.pageInfo.before = feed.entries.first?.__cursor
        }
        
        private func mergeFeedsForNewPageOfFeed(feed: Knock.Feed) {
            self.feed.entries.insert(contentsOf: feed.entries, at: feed.entries.count - 1)
            self.feed.meta = feed.meta
            self.feed.pageInfo.after = feed.pageInfo.after
        }
        
    }
}
