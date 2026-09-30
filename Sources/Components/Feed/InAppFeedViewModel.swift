//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/10/24.
//

import Foundation
import Combine

extension Knock {
    @MainActor
    public final class InAppFeedViewModel: ObservableObject {
        @Published public var feed: Knock.Feed = Knock.Feed() /// The current feed data.
        @Published public var filterOptions: [InAppFeedFilter] /// Available filter options for the feed.
        @Published public var topButtonActions: [Knock.FeedTopActionButtonType]? /// Actions available at the top of the feed interface.
        @Published internal var brandingRequired: Bool = true
        @Published var showRefreshIndicator: Bool = false
        @Published public var currentFilter: InAppFeedFilter { /// The currently selected filter for displaying feed items.
            didSet {
                filterDidChange()
            }
        }
        
        public var feedClientOptions: Knock.FeedClientOptions /// Configuration options for feed.
        public var didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>() /// Publisher for feed item button tap events.
        public var didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>() /// Publisher for feed item row tap events.
        
        public var shouldHideArchived: Bool {
            (feedClientOptions.archived == .exclude || feedClientOptions.archived == nil)
        }
        
        private let feedManagerProvider: @MainActor () -> Knock.FeedManager?
        private var newMessagesTask: Task<Void, Never>?
        
        // MARK: Initialization
        
        public convenience init(
            feedClientOptions: Knock.FeedClientOptions = .init(),
            currentFilter: InAppFeedFilter? = nil,
            filterOptions: [InAppFeedFilter]? = nil,
            topButtonActions: [Knock.FeedTopActionButtonType]? = [.markAllAsRead(), .archiveRead()]
        ) {
            self.init(
                feedClientOptions: feedClientOptions,
                currentFilter: currentFilter,
                filterOptions: filterOptions,
                topButtonActions: topButtonActions,
                feedManagerProvider: { Knock.shared.feedManager }
            )
        }
        
        internal init(
            feedClientOptions: Knock.FeedClientOptions,
            currentFilter: InAppFeedFilter?,
            filterOptions: [InAppFeedFilter]?,
            topButtonActions: [Knock.FeedTopActionButtonType]?,
            feedManagerProvider: @escaping @MainActor () -> Knock.FeedManager?
        ) {
            self.feedClientOptions = feedClientOptions
            self.filterOptions = filterOptions ?? [.init(scope: .all), .init(scope: .unread), .init(scope: .archived)]
            self.currentFilter = currentFilter ?? filterOptions?.first ?? .init(scope: .all)
            self.topButtonActions = topButtonActions
            self.feedManagerProvider = feedManagerProvider
            self.feedClientOptions.status = self.currentFilter.scope
        }
        
        deinit {
            newMessagesTask?.cancel()
        }
        
        /// The manager whose new messages are being observed. Requests go through it so they match the realtime feed.
        /// Weak, since only its owner's release shuts its connection down.
        private weak var observedFeedManager: Knock.FeedManager?

        private var feedManager: Knock.FeedManager? {
            observedFeedManager ?? feedManagerProvider()
        }
        
        // MARK: Public Methods
        
        /// Connects to the feed, refreshes it, and prepends new messages as they arrive. Calling this again replaces the previous observation.
        public func connectFeedAndObserveNewMessages() async {
            guard let feedManager = feedManagerProvider() else {
                Knock.shared.log(type: .warning, category: .feed, message: "connectFeedAndObserveNewMessages", status: .fail, errorMessage: "No feed manager is set")
                return
            }
            feedManager.connectToFeed()
            observeNewMessages(from: feedManager)
            
            brandingRequired = await getBrandingRequired(feedManager: feedManager)
            await refreshFeed(showRefreshIndicator: false)
        }
        
        /// Stops observing new messages. The feed manager's connection is left as is.
        public func stopObservingNewMessages() {
            newMessagesTask?.cancel()
            newMessagesTask = nil
            observedFeedManager = nil
        }

        public func refreshFeed(showRefreshIndicator: Bool = false) async {
            if showRefreshIndicator {
                self.showRefreshIndicator = true
            }
            defer {
                if showRefreshIndicator {
                    self.showRefreshIndicator = false
                }
            }
            
            do {
                guard let feedManager else { return }
                var userFeed = try await feedManager.getUserFeedContent(options: requestOptions())
                userFeed.pageInfo.before = userFeed.entries.first?.__cursor
                feed = userFeed
            } catch {
                handleFeedError(error)
            }
        }
        
        public func fetchNewPageOfFeedItems() async {
            guard let after = feed.pageInfo.after, let feedManager else { return }
            do {
                let newFeed = try await feedManager.getUserFeedContent(options: requestOptions(after: after))
                mergeFeedsForNewPageOfFeed(feed: newFeed)
            } catch {
                handleFeedError(error)
            }
        }
        
        public func isMoreContentAvailable() -> Bool {
            return feed.pageInfo.after != nil
        }
        
        // MARK: Message Egagement Status Updates
        
        
        public func bulkUpdateMessageEngagementStatus(
            updatedStatus: Knock.KnockMessageStatusUpdateType,
            archivedScope: Knock.FeedItemScope = .all /// The scope will determine which FeedItems are archived (Only applicable when status is .archived)
        ) async {
            switch updatedStatus {
            case .seen: guard feed.meta.unseenCount > 0 else { return }
            case .read: guard feed.meta.unreadCount > 0 else { return }
            default: break
            }
            
            let feedOptions = Knock.FeedClientOptions(status: archivedScope, tenant: feedClientOptions.tenant, has_tenant: feedClientOptions.has_tenant, archived: feedClientOptions.archived)
            do {
                _ = try await feedManager?.makeBulkStatusUpdate(type: updatedStatus, options: feedOptions)
                optimisticallyBulkUpdateStatus(updatedStatus: updatedStatus, archivedScope: archivedScope)
            } catch {
                logError("Failed: bulkUpdateMessageStatus for status: \(updatedStatus.rawValue)", error)
            }
        }
        
        public func updateMessageEngagementStatus(_ item: Knock.FeedItem, updatedStatus: Knock.KnockMessageStatusUpdateType) async {
            switch updatedStatus {
            case .seen: guard item.seen_at == nil else { return }
            case .read: guard item.read_at == nil else { return }
            case .interacted: guard item.interacted_at == nil else { return }
            case .archived: guard item.archived_at == nil else { return }
            case .unread: guard item.read_at != nil else { return }
            case .unseen: guard item.seen_at != nil else { return }
            case .unarchived: guard item.archived_at != nil else { return }
            }
            do {
                _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: updatedStatus)
                optimisticallyUpdateStatusForItem(item: item, status: updatedStatus)
                await fetchNewMetaData()
            } catch {
                logError("Failed: updateMessageStatus for status: \(updatedStatus.rawValue)", error)
            }
        }
        
        
        // MARK: FeedItemRow Interactions
        
        public func feedItemButtonTapped(item: Knock.FeedItem, actionString: String) {
            didTapFeedItemButtonPublisher.send(actionString)
        }
        
        public func feedItemRowTapped(item: Knock.FeedItem) {
            didTapFeedItemRowPublisher.send(item)
            Task {
                await updateMessageEngagementStatus(item, updatedStatus: .interacted)
            }
        }
        
        // MARK: Button/Swipe Interactions
        
        public func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction, useInverse: Bool) {
            Task {
                switch swipeAction {
                case .archive: await updateMessageEngagementStatus(item, updatedStatus: useInverse ? .unarchived : .archived)
                case .markAsRead: await updateMessageEngagementStatus(item, updatedStatus: useInverse ? .unread : .read)
                }
            }
        }
        
        public func topActionButtonTapped(action: Knock.FeedTopActionButtonType) async {
            switch action {
            case .archiveAll(_): await bulkUpdateMessageEngagementStatus(updatedStatus: .archived)
            case .archiveRead(_): await bulkUpdateMessageEngagementStatus(updatedStatus: .archived, archivedScope: .read)
            case .markAllAsRead(_): await bulkUpdateMessageEngagementStatus(updatedStatus: .read)
            }
        }
        
        // MARK: Internal Methods
        
        /// The options for a feed request. The archived filter is sent as `archived: only` with an unfiltered status, since `archived` isn't a status the API accepts.
        internal func requestOptions(before: String? = nil, after: String? = nil) -> Knock.FeedClientOptions {
            var options = feedClientOptions
            if options.status == .archived {
                options.status = .all
                options.archived = .only
            }
            options.before = before
            options.after = after
            return options
        }
        
        internal func handleNewMessageEvent(from feedManager: Knock.FeedManager) async {
            do {
                let newFeed = try await feedManager.getUserFeedContent(options: requestOptions(before: feed.pageInfo.before))
                mergeFeedsForNewMessageReceived(feed: newFeed)
            } catch {
                handleFeedError(error)
            }
        }
        
        internal func mergeFeedsForNewMessageReceived(feed newFeed: Knock.Feed) {
            let existingIds = Set(feed.entries.map(\.id))
            let newEntries = newFeed.entries.filter { !existingIds.contains($0.id) }
            feed.entries.insert(contentsOf: newEntries, at: 0)
            feed.meta = newFeed.meta
            if let cursor = newFeed.entries.first?.__cursor {
                feed.pageInfo.before = cursor
            }
        }
        
        internal func mergeFeedsForNewPageOfFeed(feed newFeed: Knock.Feed) {
            let existingIds = Set(feed.entries.map(\.id))
            feed.entries.append(contentsOf: newFeed.entries.filter { !existingIds.contains($0.id) })
            feed.meta = newFeed.meta
            feed.pageInfo.after = newFeed.pageInfo.after
        }
        
        internal func optimisticallyBulkUpdateStatus(
            updatedStatus: Knock.KnockMessageStatusUpdateType,
            archivedScope: Knock.FeedItemScope = .all
        ) {
            let date = Date()
            let updatedEntries = updateEntriesStatus(entries: feed.entries, status: updatedStatus, date: date, archivedScope: archivedScope)
            
            // Filter entries based on the currentFilter
            let filteredEntries = currentFilter.scope != .all ? filterEntries(entries: updatedEntries, scope: currentFilter.scope) : updatedEntries
            
            feed.entries = filteredEntries
            optimisticallyUpdateMetaCounts(status: updatedStatus)
        }

        internal func optimisticallyUpdateStatusForItem(item: Knock.FeedItem, status: Knock.KnockMessageStatusUpdateType) {
            guard let index = feed.entries.firstIndex(where: { $0.id == item.id }) else { return }
            switch status {
            case .read:
                feed.entries[index].read_at = Date()
                if feed.meta.unreadCount > 0 {
                    feed.meta.unreadCount -= 1
                }
                if feedClientOptions.status == .unread {
                    feed.entries.remove(at: index)
                }
            case .unread:
                feed.entries[index].read_at = nil
                feed.meta.unreadCount += 1
                if feedClientOptions.status == .read {
                    feed.entries.remove(at: index)
                }
            case .seen:
                feed.entries[index].seen_at = Date()
                if feed.meta.unseenCount > 0 {
                    feed.meta.unseenCount -= 1
                }
                if feedClientOptions.status == .unseen {
                    feed.entries.remove(at: index)
                }
            case .unseen:
                feed.entries[index].seen_at = nil
                feed.meta.unseenCount += 1
                if feedClientOptions.status == .seen {
                    feed.entries.remove(at: index)
                }
            case .interacted:
                if item.read_at == nil {
                    feed.entries[index].read_at = Date()
                    if feed.meta.unreadCount > 0 {
                        feed.meta.unreadCount -= 1
                    }
                }
                feed.entries[index].interacted_at = Date()
                if feedClientOptions.status == .read {
                    feed.entries.remove(at: index)
                }
            case .archived:
                feed.entries[index].archived_at = Date()
                if shouldHideArchived {
                    feed.entries.remove(at: index)
                }
            default: break
            }
        }
        
        // MARK: Private Methods
        
        private func observeNewMessages(from feedManager: Knock.FeedManager) {
            newMessagesTask?.cancel()
            observedFeedManager = feedManager
            // The events stream finishes when the manager is released, which ends the loop.
            newMessagesTask = Task { [weak self, weak feedManager] in
                guard let events = await feedManager?.events(named: "new-message") else { return }
                for await _ in events {
                    guard let self, let feedManager else { return }
                    await self.handleNewMessageEvent(from: feedManager)
                }
            }
        }

        private func updateEntriesStatus(
            entries: [Knock.FeedItem],
            status: Knock.KnockMessageStatusUpdateType,
            date: Date,
            archivedScope: Knock.FeedItemScope
        ) -> [Knock.FeedItem] {
            return entries.compactMap { item in
                var mutableItem = item
                switch status {
                case .seen:
                    if mutableItem.seen_at == nil {
                        mutableItem.seen_at = date
                    }
                case .read:
                    if mutableItem.read_at == nil {
                        mutableItem.read_at = date
                    }
                case .interacted:
                    if mutableItem.interacted_at == nil {
                        mutableItem.interacted_at = date
                    }
                case .archived:
                    if mutableItem.archived_at == nil && shouldArchive(item: item, scope: archivedScope) {
                        mutableItem.archived_at = date
                        if self.shouldHideArchived {
                            return nil
                        }
                    }
                case .unread:
                    mutableItem.read_at = nil
                case .unseen:
                    mutableItem.seen_at = nil
                default: break
                }
                return mutableItem
            }
        }

        private func shouldArchive(item: Knock.FeedItem, scope: Knock.FeedItemScope) -> Bool {
            switch scope {
            case .interacted: return item.interacted_at != nil
            case .unread: return item.read_at == nil
            case .read: return item.read_at != nil
            case .unseen: return item.seen_at == nil
            case .seen: return item.seen_at != nil
            default: return true
            }
        }

        private func filterEntries(entries: [Knock.FeedItem], scope: Knock.FeedItemScope) -> [Knock.FeedItem] {
            return entries.filter {
                switch scope {
                case .unread: return $0.read_at == nil
                case .read: return $0.read_at != nil
                case .unseen: return $0.seen_at == nil
                case .seen: return $0.seen_at != nil
                case .archived: return $0.archived_at != nil
                default: return true
                }
            }
        }

        private func optimisticallyUpdateMetaCounts(status: Knock.KnockMessageStatusUpdateType) {
            switch status {
            case .seen: self.feed.meta.unseenCount = 0
            case .read: self.feed.meta.unreadCount = 0
            case .unread: self.feed.meta.unreadCount = self.feed.entries.count
            case .unseen: self.feed.meta.unseenCount = self.feed.entries.count
            default: break
            }
        }
        
        private func logError(_ message: String, _ error: Error) {
            Knock.shared.log(type: .error, category: .feed, message: "\(message): \(error.localizedDescription)")
        }
        
        private func filterDidChange() {
            self.feedClientOptions.status = self.currentFilter.scope
            Task { [weak self] in
                await self?.refreshFeed(showRefreshIndicator: true)
            }
        }
        
        private func fetchNewMetaData() async {
            guard let feedManager else { return }
            do {
                let latest = try await feedManager.getUserFeedContent(options: requestOptions())
                feed.meta = latest.meta
            } catch {
                handleFeedError(error)
            }
        }
        
        private func getBrandingRequired(feedManager: Knock.FeedManager) async -> Bool {
            let settings = try? await feedManager.feedModule.getFeedSettings()
            return settings?.features.brandingRequired ?? false
        }
        
        private func handleFeedError(_ error: Error) {
            Knock.shared.log(type: .error, category: .feed, message: "Feed error: \(error.localizedDescription)")
        }
    }
}
