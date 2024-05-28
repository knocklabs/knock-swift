//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/10/24.
//

import Foundation
import Combine

//extension Knock {
//    public class InAppFeedViewModel: ObservableObject {
//        @Published public var feed: Knock.Feed = Knock.Feed() /// The current feed data.
//        @Published public var currentTenantId: String? /// The tenant ID associated with the current feed.
//        @Published public var filterOptions: [InAppFeedFilter] /// Available filter options for the feed.
//        @Published public var topButtonActions: [Knock.FeedTopActionButtonType]? /// Actions available at the top of the feed interface.
//
//        @Published internal var brandingRequired: Bool = true /// Controls whether to show the Knock icon on the feed interface.
//        @Published var showRefreshIndicator: Bool = false
//        @Published public var currentFilter: InAppFeedFilter { /// The currently selected filter for displaying feed items.
//            didSet {
//                filterDidChange()
//            }
//        }
//        
//        public var feedClientOptions: Knock.FeedClientOptions /// Configuration options for feed.
//        public let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>() /// Publisher for feed item button tap events.
//        public let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>() /// Publisher for feed item row tap events.
//        
//        public var shouldHideArchived: Bool {
//            (feedClientOptions.archived == .exclude || feedClientOptions.archived == nil)
//        }
//        
//        // MARK: Initialization
//        
//        public init(
//            feedClientOptions: Knock.FeedClientOptions = .init(),
//            currentTenantId: String? = nil,
//            currentFilter: InAppFeedFilter? = nil,
//            filterOptions: [InAppFeedFilter]? = nil,
//            topButtonActions: [Knock.FeedTopActionButtonType]? = [.markAllAsRead(), .archiveRead()]
//        ) {
//            self.feedClientOptions = feedClientOptions
//            self.currentTenantId = currentTenantId ?? feedClientOptions.tenant
//            self.filterOptions = filterOptions ?? [.init(scope: .all), .init(scope: .unread), .init(scope: .archived)]
//            self.currentFilter = currentFilter ?? filterOptions?.first ?? .init(scope: .all)
//            self.topButtonActions = topButtonActions
//            
//            // Assign initial settings to _feedClientOptions to be used in API calls
//            self.feedClientOptions.status = self.currentFilter.scope
//            self.feedClientOptions.tenant = self.currentTenantId
//        }
//        
//        /// Sets up feed manager connection and subscribes to new message events.
//        public func connectFeedAndObserveNewMessages() async {
//            Knock.shared.feedManager?.connectToFeed()
//            Knock.shared.feedManager?.on(eventName: "new-message") { [weak self] _ in
//                guard let self = self else { return }
//                feedClientOptions.before = self.feed.pageInfo.before
//                Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) { result in
//                    DispatchQueue.main.async {
//                        switch result {
//                        case .success(let feed):
//                            self.mergeFeedsForNewMessageReceived(feed: feed)
//                        case .failure(let error):
//                            self.handleFeedError(error)
//                        }
//                    }
//                }
//            }
//            
//            let _ = await self.getBrandingRequired()
//            let _ = await self.refreshFeed(showRefreshIndicator: false)
//        }
//        
//        public func getBrandingRequiredStatus() async {
//            let branding = await getBrandingRequired()
//            DispatchQueue.main.async {
//                self.brandingRequired = branding
//            }
//        }
//        
//        /// Refreshes the feed by fetching the latest items based on the current settings.
//        public func refreshFeed(showRefreshIndicator: Bool = false) async {
//            do {
//                if showRefreshIndicator {
//                    DispatchQueue.main.async {
//                        self.showRefreshIndicator = true
//                    }
//                }
//                let originalStatus = feedClientOptions.status
//                let archived: Knock.FeedItemArchivedScope? = feedClientOptions.status == .archived ? .only : nil
//                let status = feedClientOptions.status == .archived ? .all : feedClientOptions.status
//                self.feedClientOptions.archived = archived
//                self.feedClientOptions.status = status
//                self.feedClientOptions.before = nil
//                self.feedClientOptions.after = nil
//                guard let userFeed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) else { return }
//                DispatchQueue.main.async {
//                    self.feed = userFeed
//                    self.feed.pageInfo.before = self.feed.entries.first?.__cursor
//                    self.feedClientOptions.status = originalStatus
//                    if self.showRefreshIndicator {
//                        self.showRefreshIndicator = false
//                    }
//                }
//            } catch {
//                handleFeedError(error)
//            }
//        }
//        
//        /// Fetches a new page of feed items when the user scrolls to the bottom of the feed.
//        public func fetchNewPageOfFeedItems() async {
//            guard let after = self.feed.pageInfo.after else { return }
//            feedClientOptions.after = after
//            Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) { result in
//                DispatchQueue.main.async {
//                    switch result {
//                    case .success(let feed):
//                        self.mergeFeedsForNewPageOfFeed(feed: feed)
//                    case .failure(let error):
//                        self.handleFeedError(error)
//                    }
//                }
//            }
//        }
//        
//        /// Determines whether there is another page of content to fetch when paginaating the feedItem list
//        public func isMoreContentAvailable() -> Bool {
//            return feed.pageInfo.after != nil
//        }
//        
//        // MARK: Message Update Methods
//        
//        /// Archives a specific feed item.
//        public func archiveItem(_ item: Knock.FeedItem) async {
//            do {
//                let message = try await Knock.shared.updateMessageStatus(messageId: item.id, status: .archived)
//                
//                if let index = self.feed.entries.firstIndex(where: { $0.id == message.id }) {
//                    DispatchQueue.main.async { [weak self] in
//                        self?.feed.entries[index].archived_at = Date()
//                        
//                        // remove local message if update was successful and the archived filter is set to `exclude` or is nil
//                        if self?.shouldHideArchived ?? true {
//                            self?.feed.entries.remove(at: index)
//                        }
//                    }
//                    await fetchNewMetaData()
//                }
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in archiveItem: \(error.localizedDescription)")
//            }
//        }
//        
//        /// Archives all items within the specified scope.sd
//        public func archiveAll(scope: Knock.FeedItemScope) async {
//            let feedOptions = Knock.FeedClientOptions(status: scope, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
//            do {
//                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .archived, options: feedOptions)
//                optimisticallyBulkUpdateStatus(status: .archived, scope: scope)
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in archiveAll: \(error.localizedDescription)")
//            }
//        }
//        
//        /// Marks all items in the feed as read.
//        public func markAllAsRead() async {
//            guard feed.meta.unreadCount > 0 else { return }
//            
//            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
//            do {
//                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .read, options: feedOptions)
//                optimisticallyBulkUpdateStatus(status: .read)
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in markAllAsRead: \(error.localizedDescription)")
//            }
//        }
//        
//        /// Marks all unseen items as seen.
//        public func markAllAsSeen() async {
//            guard feed.meta.unseenCount > 0 else { return }
//            
//            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
//            do {
//                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .seen, options: feedOptions)
//                optimisticallyBulkUpdateStatus(status: .seen)
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in markAllAsSeen: \(error.localizedDescription)")
//            }
//        }
//        
//        public func markAsRead(_ item: Knock.FeedItem) async {
//            guard item.read_at == nil else { return }
//            do {
//                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .read)
//                
//                if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
//                    await MainActor.run {
//                        feed.entries[index].read_at = Date()
//                        if feed.meta.unreadCount > 0 {
//                            feed.meta.unreadCount -= 1
//                        }
//                    }
//                }
//                
//                await fetchNewMetaData()
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in markAsRead: \(error.localizedDescription)")
//            }
//        }
//        
//        public func markAsUnread(_ item: Knock.FeedItem) async {
//            guard item.read_at != nil else { return }
//            do {
//                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .unread)
//                
//                if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
//                    await MainActor.run {
//                        feed.entries[index].read_at = nil
//                        feed.meta.unreadCount += 1
//                    }
//                }
//                
//                await fetchNewMetaData()
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in markAsUnread: \(error.localizedDescription)")
//            }
//        }
//        
//        public func markAsInteracted(_ item: Knock.FeedItem) async {
//            guard item.inserted_at == nil else { return }
//            do {
//                let _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .interacted)
//                if let index = feed.entries.firstIndex(where: { $0.id == item.id }) {
//                    await MainActor.run {
//                        if item.read_at == nil {
//                            feed.entries[index].read_at = Date()
//                            if feed.meta.unreadCount > 0 {
//                                feed.meta.unreadCount -= 1
//                            }
//                        }
//                        feed.entries[index].interacted_at = Date()
//                    }
//                }
//            } catch {
//                Knock.shared.log(type: .error, category: .feed, message: "error in markAsInteracted: \(error.localizedDescription)")
//            }
//        }
//        
//        public func optimisticallyBulkUpdateStatus(status: Knock.KnockMessageStatusBatchUpdateType, scope: Knock.FeedItemScope = .all) {
//            let date = Date()
//            var meta = feed.meta
//            var entries = feed.entries
//            if scope != .all {
//                entries = entries.filter({ item in
//                    switch scope {
//                    case .unread: item.read_at == nil
//                    case .read: item.read_at != nil
//                    case .unseen: item.seen_at == nil
//                    case .seen: item.seen_at != nil
//                    case .archived: item.archived_at != nil
//                    default: true
//                    }
//                })
//            }
//            DispatchQueue.main.async {
//                entries = entries.map { item in
//                    var newItem = item
//                    switch status {
//                    case .seen:
//                        if newItem.seen_at == nil {
//                            newItem.seen_at = date
//                        }
//                    case .read:
//                        if newItem.read_at == nil {
//                            newItem.read_at = date
//                        }
//                    case .interacted:
//                        if newItem.interacted_at == nil {
//                            newItem.interacted_at = date
//                        }
//                    case .archived:
//                        if newItem.archived_at == nil {
//                            newItem.archived_at = date
//                        }
//                    case .unread:
//                        newItem.read_at = nil
//                    case .unseen:
//                        newItem.seen_at = nil
//                    default: break
//                    }
//                    
//                    return newItem
//                }
//                
//                self.feed.entries = entries
//                
//                switch status {
//                case .seen: self.feed.meta.unseenCount = 0
//                case .read: self.feed.meta.unreadCount = 0
//                case .unread: self.feed.meta.unseenCount = self.feed.entries.count
//                case .unseen: self.feed.meta.unseenCount = self.feed.entries.count
//                default: break
//                }
//            }
//        }
//        
//        // MARK: FeedItemRow Interactions
//        public func feedItemButtonTapped(item: Knock.FeedItem, actionString: String) {
//            didTapFeedItemButtonPublisher.send(actionString)
//        }
//        
//        public func feedItemRowTapped(item: Knock.FeedItem) {
//            didTapFeedItemRowPublisher.send(item)
//            Task {
//                await markAsInteracted(item)
//            }
//        }
//        
//        // MARK: Button/Swipe Interactions
//        
//        /// Called when a user performs a horizontal swipe action on a row item.
//        public func didSwipeRow(item: Knock.FeedItem, swipeAction: FeedNotificationRowSwipeAction) {
//            Task {
//                switch swipeAction {
//                case .archive: await archiveItem(item)
//                case .markAsRead: await markAsRead(item)
//                case .markAsUnread: await markAsUnread(item)
//                }
//            }
//        }
//        
//        /// Called when a user taps on one of the action buttons at the top of the list.
//        public func topActionButtonTapped(action: Knock.FeedTopActionButtonType) async {
//            switch action {
//            case .archiveAll(_):
//                await archiveAll(scope: .all)
//            case .archiveRead(_):
//                await archiveAll(scope: .read)
//            case .markAllAsRead(_):
//                await markAllAsRead()
//            }
//        }
//        
//        // MARK: Private Methods
//        
//        private func filterDidChange() {
//            self.feedClientOptions.status = self.currentFilter.scope
//
//            Task { [weak self] in
//                await self?.refreshFeed(showRefreshIndicator: true)
//            }
//        }
//        
//        private func fetchNewMetaData() async {
//            do {
//                if let feed = try await Knock.shared.feedManager?.getUserFeedContent(options: feedClientOptions) {
//                    DispatchQueue.main.async {
//                        self.feed.meta = feed.meta
//                    }
//                }
//            } catch {
//                handleFeedError(error)
//            }
//        }
//        
//        private func mergeFeedsForNewMessageReceived(feed: Knock.Feed) {
//            self.feed.entries.insert(contentsOf: feed.entries, at: 0)
//            self.feed.meta = feed.meta
//            self.feed.pageInfo.before = feed.entries.first?.__cursor
//        }
//        
//        private func mergeFeedsForNewPageOfFeed(feed: Knock.Feed) {
//            self.feed.entries.insert(contentsOf: feed.entries, at: feed.entries.count - 1)
//            self.feed.meta = feed.meta
//            self.feed.pageInfo.after = feed.pageInfo.after
//        }
//        
//        private func getBrandingRequired() async -> Bool {
//            let settings = try? await Knock.shared.feedManager?.feedModule.getFeedSettings()
//            return settings?.features.brandingRequired ?? false
//        }
//        
//        private func handleFeedError(_ error: Error) {
//            Knock.shared.log(type: .error, category: .feed, message: "Feed error: \(error.localizedDescription)")
//        }
//    }
//}

extension Knock {
    public class InAppFeedViewModel: ObservableObject {
        @Published public var feed: Knock.Feed = Knock.Feed()
        @Published public var currentTenantId: String?
        @Published public var filterOptions: [InAppFeedFilter]
        @Published public var topButtonActions: [Knock.FeedTopActionButtonType]?
        @Published internal var brandingRequired: Bool = true
        @Published var showRefreshIndicator: Bool = false
        @Published public var currentFilter: InAppFeedFilter {
            didSet {
                filterDidChange()
            }
        }
        
        public var feedClientOptions: Knock.FeedClientOptions
        public let didTapFeedItemButtonPublisher = PassthroughSubject<String, Never>()
        public let didTapFeedItemRowPublisher = PassthroughSubject<Knock.FeedItem, Never>()
        
        public var shouldHideArchived: Bool {
            (feedClientOptions.archived == .exclude || feedClientOptions.archived == nil)
        }
        
        private var cancellables = Set<AnyCancellable>()
        
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
            
            self.feedClientOptions.status = self.currentFilter.scope
            self.feedClientOptions.tenant = self.currentTenantId
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
        
        public func archiveItem(_ item: Knock.FeedItem) async {
            do {
                _ = try await Knock.shared.updateMessageStatus(messageId: item.id, status: .archived)
                await optimisticallyUpdateStatusForItem(item: item, status: .archived)
                await fetchNewMetaData()
            } catch {
                logError("archiveItem", error)
            }
        }
        
        public func archiveAll(scope: Knock.FeedItemScope) async {
            let feedOptions = Knock.FeedClientOptions(status: scope, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .archived, options: feedOptions)
                await optimisticallyBulkUpdateStatus(status: .archived, scope: scope)
            } catch {
                logError("archiveAll", error)
            }
        }
        
        public func markAllAsRead() async {
            guard feed.meta.unreadCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .read, options: feedOptions)
                await optimisticallyBulkUpdateStatus(status: .read)
            } catch {
                logError("markAllAsRead", error)
            }
        }
        
        public func markAllAsSeen() async {
            guard feed.meta.unseenCount > 0 else { return }
            
            let feedOptions = Knock.FeedClientOptions(status: .all, tenant: currentTenantId, has_tenant: feedClientOptions.has_tenant, archived: nil)
            do {
                _ = try await Knock.shared.feedManager?.makeBulkStatusUpdate(type: .seen, options: feedOptions)
                await optimisticallyBulkUpdateStatus(status: .seen)
            } catch {
                logError("markAllAsSeen", error)
            }
        }
        
        public func markAsRead(_ item: Knock.FeedItem) async {
            guard item.read_at == nil else { return }
            do {
                _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .read)
                await optimisticallyUpdateStatusForItem(item: item, status: .read)
                await fetchNewMetaData()
            } catch {
                logError("markAsRead", error)
            }
        }
        
        public func markAsUnread(_ item: Knock.FeedItem) async {
            guard item.read_at != nil else { return }
            do {
                _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .unread)
                await optimisticallyUpdateStatusForItem(item: item, status: .unread)
                await fetchNewMetaData()
            } catch {
                logError("markAsUnread", error)
            }
        }
        
        public func markAsInteracted(_ item: Knock.FeedItem) async {
            guard item.inserted_at == nil else { return }
            do {
                _ = try await Knock.shared.messageModule.updateMessageStatus(messageId: item.id, status: .interacted)
                await optimisticallyUpdateStatusForItem(item: item, status: .interacted)
                await fetchNewMetaData()
            } catch {
                logError("markAsInteracted", error)
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
        
        internal func optimisticallyBulkUpdateStatus(status: Knock.KnockMessageStatusBatchUpdateType, scope: Knock.FeedItemScope = .all) async {
            let date = Date()
            var entries = feed.entries
            
            if scope != .all {
                entries = entries.filter {
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
            
            let updatedEntries = entries.map { item in
                var newItem = item
                switch status {
                case .seen:
                    if newItem.seen_at == nil {
                        newItem.seen_at = date
                    }
                case .read:
                    if newItem.read_at == nil {
                        newItem.read_at = date
                    }
                case .interacted:
                    if newItem.interacted_at == nil {
                        newItem.interacted_at = date
                    }
                case .archived:
                    if newItem.archived_at == nil {
                        newItem.archived_at = date
                    }
                case .unread:
                    newItem.read_at = nil
                case .unseen:
                    newItem.seen_at = nil
                default: break
                }
                return newItem
            }
            
            await MainActor.run {
                
                if status == .archived && self.shouldHideArchived {
                    self.feed.entries = []
                } else {
                    self.feed.entries = updatedEntries
                }
                
                switch status {
                case .seen: self.feed.meta.unseenCount = 0
                case .read: self.feed.meta.unreadCount = 0
                case .unread: self.feed.meta.unreadCount = self.feed.entries.count
                case .unseen: self.feed.meta.unseenCount = self.feed.entries.count
                default: break
                }
            }
        }

        internal func optimisticallyUpdateStatusForItem(item: Knock.FeedItem, status: Knock.KnockMessageStatusBatchUpdateType) async {
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
            self.feed.entries.insert(contentsOf: feed.entries, at: 0)
            self.feed.meta = feed.meta
            self.feed.pageInfo.before = feed.entries.first?.__cursor
        }
        
        private func mergeFeedsForNewPageOfFeed(feed: Knock.Feed) {
            self.feed.entries.append(contentsOf: feed.entries)
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
