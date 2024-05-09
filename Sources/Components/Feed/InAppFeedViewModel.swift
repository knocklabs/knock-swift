//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/10/24.
//

import Foundation
import Combine

extension Knock {
    public class InAppFeedViewModel: ObservableObject {
        @Published public var feed: Knock.Feed = Knock.Feed() /// The current feed data.
        @Published public var currentTenantId: String? /// The tenant ID associated with the current feed.
        @Published public var filterOptions: [InAppFeedFilter] /// Available filter options for the feed.
        @Published public var topButtonActions: [Knock.FeedTopActionButtonType]? /// Actions available at the top of the feed interface.

        @Published internal var brandingRequired: Bool = true /// Controls whether to show the Knock icon on the feed interface.
        @Published var showRefreshIndicator: Bool = false
        @Published public var currentFilter: InAppFeedFilter { /// The currently selected filter for displaying feed items.
            didSet {
                filterDidChange()
            }
        }
        
        public var feedClientOptions: Knock.FeedClientOptions /// Configuration options for feed.
        public let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>() /// Publisher for feed item button tap events.
        public let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>() /// Publisher for feed item row tap events.
        
        // MARK: Initialization
        
        public init(
            feedClientOptions: Knock.FeedClientOptions = .init(),
            currentTenantId: String? = nil,
            currentFilter: InAppFeedFilter? = nil,
            filterOptions: [InAppFeedFilter]? = nil,
            topButtonActions: [Knock.FeedTopActionButtonType]? = [.markAllAsRead(), .archiveRead()]
        ) {
            self.feedClientOptions = feedClientOptions
            self.currentTenantId = currentTenantId ?? feedClientOptions.tenant
            self.filterOptions = filterOptions ?? [.init(scope: .all), .init(scope: .unread), .init(scope: .archived)]
            self.currentFilter = currentFilter ?? filterOptions?.first ?? .init(scope: .all)
            self.topButtonActions = topButtonActions
            
            // Assign initial settings to _feedClientOptions to be used in API calls
            self.feedClientOptions.status = self.currentFilter.scope
            self.feedClientOptions.tenant = self.currentTenantId
        }
        
        /// Sets up feed manager connection and subscribes to new message events.
        public func connectFeedAndObserveNewMessages() async {
            Knock.shared.feedManager?.connectToFeed()
            Knock.shared.feedManager?.on(eventName: "new-message") { [weak self] _ in
                guard let self = self else { return }
                feedClientOptions.before = self.feed.pageInfo.before
                Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let feed):
                            self.mergeFeedsForNewMessageReceived(feed: feed)
                        case .failure(let error):
                            self.handleFeedError(error)
                        }
                    }
                }
            }
            await refreshFeed(showRefreshIndicator: true)
            let branding = await getBrandingRequired()
            DispatchQueue.main.async {
                self.brandingRequired = branding
            }
        }
        
        /// Refreshes the feed by fetching the latest items based on the current settings.
        public func refreshFeed(showRefreshIndicator: Bool = false) async {
            do {
                if showRefreshIndicator {
                    DispatchQueue.main.async {
                        self.showRefreshIndicator = true
                    }
                }
                let originalStatus = feedClientOptions.status
                let archived: Knock.FeedItemArchivedScope? = feedClientOptions.status == .archived ? .only : nil
                let status = feedClientOptions.status == .archived ? .all : feedClientOptions.status
                self.feedClientOptions.archived = archived
                self.feedClientOptions.status = status
                self.feedClientOptions.before = nil
                self.feedClientOptions.after = nil
                guard let userFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
                DispatchQueue.main.async {
                    self.feed = userFeed
                    self.feed.pageInfo.before = self.feed.entries.first?.__cursor
                    self.feedClientOptions.status = originalStatus
                    if self.showRefreshIndicator {
                        self.showRefreshIndicator = false
                    }
                }
            } catch {
                handleFeedError(error)
            }
        }
        
        /// Fetches a new page of feed items when the user scrolls to the bottom of the feed.
        public func fetchNewPageOfFeedItems() async {
            guard let after = self.feed.pageInfo.after else { return }
            feedClientOptions.after = after
            Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let feed):
                        self.mergeFeedsForNewPageOfFeed(feed: feed)
                    case .failure(let error):
                        self.handleFeedError(error)
                    }
                }
            }
        }
        
        /// Determines whether there is another page of content to fetch when paginaating the feedItem list
        public func isMoreContentAvailable() -> Bool {
            return feed.pageInfo.after != nil
        }
        
        // MARK: Message Update Methods
        
        /// Archives a specific feed item.
        public func archiveItem(_ item: Knock.FeedItem) async {
            do {
                let message = try await Knock.shared.updateMessageStatus(messageId: item.id, status: .archived)
                
                // remove local message if update was successful
                DispatchQueue.main.async {
                    self.feed.entries = self.feed.entries.filter{ $0.id != message.id }
                }
                await fetchNewMetaData()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in archiveItem: \(error.localizedDescription)")
            }
        }
        
        /// Archives all items within the specified scope.
        public func archiveAll(scope: Knock.FeedItemScope) async {
            let feedOptions = Knock.FeedClientOptions(status: scope, tenant: currentTenantId, has_tenant: false, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .archived, options: feedOptions)
                await refreshFeed()
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in archiveAll: \(error.localizedDescription)")
            }
        }
        
        /// Marks all items in the feed as read.
        public func markAllAsRead() async {
            guard feed.meta.unreadCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: false, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .read, options: feedOptions)
                DispatchQueue.main.async {
                    self.feed.meta.unreadCount = 0
                    let date = Date()
                    self.feed.entries = self.feed.entries.map { item in
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
        
        /// Marks all unseen items as seen.
        public func markAllAsSeen() async {
            guard feed.meta.unseenCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: false, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .seen, options: feedOptions)
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
        
        // MARK: Button/Swipe Interactions
        
        /// Called when a user performs a horizontal swipe action on a row item.
        public func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction) {
            Task {
                switch swipeAction {
                case .archive: await archiveItem(item)
                case .markAsRead: await markAsRead(item)
                case .markAsUnread: await markAsUnread(item)
                }
            }
        }
        
        /// Called when a user taps on one of the action buttons at the top of the list.
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
        
        // MARK: Private Methods
        
        private func filterDidChange() {
            self.feedClientOptions.status = self.currentFilter.scope

            Task { [weak self] in
                await self?.refreshFeed(showRefreshIndicator: true)
            }
        }
        
        private func fetchNewMetaData() async {
            do {
                let options = Knock.FeedClientOptions(tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant)
                if let feed = try await Knock.shared.feedManager?.getUserFeedContent(options: options) {
                    DispatchQueue.main.async {
                        self.feed.meta = feed.meta
                    }
                }
            } catch {
                handleFeedError(error)
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
        
        private func getBrandingRequired() async -> Bool {
            let settings = try? await Knock.shared.feedManager?.feedModule.getFeedSettings()
            return settings?.features.brandingRequired ?? false
        }
        
        private func handleFeedError(_ error: Error) {
            Knock.shared.log(type: .error, category: .feed, message: "Feed error: \(error.localizedDescription)")
        }
    }
}
