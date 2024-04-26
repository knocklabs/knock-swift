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
        @Published public var tenantId: String? /// The tenant ID associated with the current feed.
        @Published public var currentFilter: InAppFeedFilter /// The currently selected filter for displaying feed items.
        @Published public var hasTenant: Bool? /// Flag indicating whether the feed is associated with a specific tenant.
        @Published public var filterOptions: [InAppFeedFilter] /// Available filter options for the feed.
        @Published public var topButtonActions: [Knock.FeedTopActionButtonType]? /// Actions available at the top of the feed interface.
        @Published public var feedIsLoading: Bool = false /// Whether or not to display the main loading indicator in the view

        @Published internal var shouldShowKnockIcon: Bool = true /// Controls whether to show the Knock icon on the feed interface.
        
        public let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>() /// Publisher for feed item button tap events.
        public let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>() /// Publisher for feed item row tap events.
        
        public var feedClientOptions: Knock.FeedClientOptions /// Configuration options for feed client interactions.
        private var _feedClientOptions: Knock.FeedClientOptions = .init() /// Temporary configuration options for modifying feed query without losing initial settings.
        
        private var cancellables = Set<AnyCancellable>() /// Subscription cancellables for Combine.
        
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
            self.currentFilter = currentFilter ?? filterOptions?.first ?? .init(scope: .all)
            self.topButtonActions = topButtonActions
            
            // Assign initial settings to _feedClientOptions to be used in API calls
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
        
        /// Sets up feed manager connection and subscribes to new message events.
        public func connectFeedAndObserveNewMessages() async {
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
                            self.handleFeedError(error)
                        }
                    }
                }
            }
            await refreshFeed(showLoadingIndicator: true)
            await getUserSettings()
        }
        
        /// Refreshes the feed by fetching the latest items based on the current settings.
        public func refreshFeed(showLoadingIndicator: Bool) async {
            do {
//                if showLoadingIndicator {
//                    // Update loading state immediately, but ensure any subsequent updates are deferred until after any asynchronous operations.
//                    DispatchQueue.main.async {
//                        self.feedIsLoading = true
//                    }
//                }
                let archived: Knock.FeedItemArchivedScope? = feedClientOptions.status == .archived ? .only : nil
                let scope = feedClientOptions.status == .archived ? .all : feedClientOptions.status
                self.feedClientOptions.archived = archived
                self._feedClientOptions.archived = archived
                self.feedClientOptions.status = scope
                self._feedClientOptions.status = scope

                self.feedClientOptions.tenant = tenantId
                self._feedClientOptions = feedClientOptions
                guard let userFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
                DispatchQueue.main.async {
                    // Ensure this update is done completely outside of the view update cycle
                    self.feed = userFeed
                    self.feed.pageInfo.before = self.feed.entries.first?.__cursor
//                    self.feedIsLoading = false
                }
            } catch {
                handleFeedError(error)
            }
        }
        
        /// Fetches a new page of feed items when the user scrolls to the bottom of the feed.
        public func fetchNewPageOfFeedItems() async {
            guard let after = self.feed.pageInfo.after else { return }
            _feedClientOptions.after = after
            Knock.shared.feedManager?.getUserFeedContent(options: _feedClientOptions) { result in
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
        
        public func archiveAll(scope: Knock.FeedItemScope) async {
            let feedOptions = Knock.FeedClientOptions(status: scope, tenant: tenantId, has_tenant: false, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .archived, options: feedOptions)
                await refreshFeed(showLoadingIndicator: false)
            } catch {
                Knock.shared.log(type: .error, category: .feed, message: "error in archiveAll: \(error.localizedDescription)")
            }
        }
        
        public func markAllAsRead() async {
            guard feed.meta.unreadCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: tenantId, has_tenant: false, archived: nil)
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
        
        public func markAllAsSeen() async {
            guard feed.meta.unseenCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: tenantId, has_tenant: false, archived: nil)
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
        public func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction) {
            Task {
                switch swipeAction {
                case .archive: await archiveItem(item)
                case .markAsRead: await markAsRead(item)
                case .markAsUnread: await markAsUnread(item)
                }
            }
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
        
        // MARK: Private Methods
        
        private func filterDidChange() {
            Task { [weak self] in
                self?.feedClientOptions.status = self?.currentFilter.scope
                self?._feedClientOptions.status = self?.currentFilter.scope
                await self?.refreshFeed(showLoadingIndicator: true)
            }
        }
        
        private func fetchNewMetaData() async {
            do {
                let options = Knock.FeedClientOptions(tenant: tenantId, has_tenant: true)
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
        
        private func getUserSettings() async {
            // TODO
        }
        
        private func handleFeedError(_ error: Error) {
            Knock.shared.log(type: .error, category: .feed, message: "Feed error: \(error.localizedDescription)")
        }
    }
}
