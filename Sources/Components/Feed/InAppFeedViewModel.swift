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
        
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: Initialization
        
        public init(
            feedClientOptions: Knock.FeedClientOptions = .init(),
            currentFilter: InAppFeedFilter? = nil,
            filterOptions: [InAppFeedFilter]? = nil,
            topButtonActions: [Knock.FeedTopActionButtonType]? = [.markAllAsRead(), .archiveRead()]
        ) {
            self.feedClientOptions = feedClientOptions
            self.filterOptions = filterOptions ?? [.init(scope: .all), .init(scope: .unread), .init(scope: .archived)]
            self.currentFilter = currentFilter ?? filterOptions?.first ?? .init(scope: .all)
            self.topButtonActions = topButtonActions
            self.feedClientOptions.status = self.currentFilter.scope
        }
        
        // MARK: Public Methods
        
        public func connectFeedAndObserveNewMessages() async {
            Knock.shared.feedManager?.connectToFeed()
            Knock.shared.feedManager?.on(eventName: "new-message") { [weak self] _ in
                guard let self = self else { return }
                self.feedClientOptions.before = self.feed.pageInfo.before
                Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) { result in
                    switch result {
                    case .success(let newFeed):
                        self.mergeFeedsForNewMessageReceived(feed: newFeed)
                    case .failure(let error):
                        self.handleFeedError(error)
                    }
                }
            }
            
            let required = await getBrandingRequired()
            await MainActor.run { [weak self] in
                self?.brandingRequired = required
            }
            
            await refreshFeed(showRefreshIndicator: false)
        }

        public func refreshFeed(showRefreshIndicator: Bool = false) async {
            if showRefreshIndicator {
                await MainActor.run { self.showRefreshIndicator = true }
            }
            
            let originalStatus = feedClientOptions.status
            let archived: Knock.FeedItemArchivedScope? = feedClientOptions.status == .archived ? .only : nil
            let status = feedClientOptions.status == .archived ? .all : feedClientOptions.status
            feedClientOptions.archived = archived
            feedClientOptions.status = status
            feedClientOptions.before = nil
            feedClientOptions.after = nil
            
            guard let userFeed = try? await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
            
            await MainActor.run {
                self.feed = userFeed
                self.feed.pageInfo.before = self.feed.entries.first?.__cursor
                self.feedClientOptions.status = originalStatus
                if self.showRefreshIndicator {
                    self.showRefreshIndicator = false
                }
            }
        }
        
        public func fetchNewPageOfFeedItems() async {
            guard let after = self.feed.pageInfo.after else { return }
            feedClientOptions.after = after
            do {
                guard let newFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
                self.mergeFeedsForNewPageOfFeed(feed: newFeed)
            } catch {
                self.handleFeedError(error)
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
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: updatedStatus, options: feedOptions)
                await optimisticallyBulkUpdateStatus(updatedStatus: updatedStatus, archivedScope: archivedScope)
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
                await optimisticallyUpdateStatusForItem(item: item, status: updatedStatus)
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
        
        // MARK: Private Methods
        
        internal func optimisticallyBulkUpdateStatus(
            updatedStatus: Knock.KnockMessageStatusUpdateType,
            archivedScope: Knock.FeedItemScope = .all
        ) async {
            let date = Date()
            let updatedEntries = updateEntriesStatus(entries: feed.entries, status: updatedStatus, date: date, archivedScope: archivedScope)
            
            // Filter entries based on the currentFilter
            let filteredEntries = currentFilter.scope != .all ? filterEntries(entries: updatedEntries, scope: currentFilter.scope) : updatedEntries
            
            await MainActor.run {
                self.feed.entries = filteredEntries
                optimisticallyUpdateMetaCounts(status: updatedStatus)
            }
        }

        private func updateEntriesStatus(
            entries: [Knock.FeedItem],
            status: Knock.KnockMessageStatusUpdateType,
            date: Date,
            archivedScope: Knock.FeedItemScope
        ) -> [Knock.FeedItem] {
            return entries.map { item in
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
            }.compactMap { $0 }
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

        internal func optimisticallyUpdateStatusForItem(item: Knock.FeedItem, status: Knock.KnockMessageStatusUpdateType) async {
            if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
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
            do {
                if let feed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) {
                    await MainActor.run {
                        self.feed.meta = feed.meta
                    }
                }
            } catch {
                handleFeedError(error)
            }
        }
        
        private func mergeFeedsForNewMessageReceived(feed: Knock.Feed) {
            DispatchQueue.main.async {
                self.feed.entries.insert(contentsOf: feed.entries, at: 0)
                self.feed.meta = feed.meta
                self.feed.pageInfo.before = feed.entries.first?.__cursor
            }
        }
        
        private func mergeFeedsForNewPageOfFeed(feed: Knock.Feed) {
            DispatchQueue.main.async {
                self.feed.entries.append(contentsOf: feed.entries)
                self.feed.meta = feed.meta
                self.feed.pageInfo.after = feed.pageInfo.after
            }
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
