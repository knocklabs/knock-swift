//
//  KnockInAppFeedView.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

extension Knock {
    public struct InAppFeedView: View {
        @EnvironmentObject public var viewModel: InAppFeedViewModel
        public var theme: InAppFeedTheme = .init()
        
        public init(theme: InAppFeedTheme = .init()) {
            self.theme = theme
        }
        @State private var selectedItemId: String? = nil
        @State private var redacted: Bool = false
        
        public var body: some View {
            VStack(alignment: .leading, spacing: .zero) {
                topSectionView()
                
                ZStack(alignment: .bottom) {
                    Group {
                        if viewModel.showRefreshIndicator {
                            VStack(alignment: .center) {
                                ProgressView()
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(48)
                        } else if viewModel.feed.entries.isEmpty {
                            Knock.EmptyFeedView(config: viewModel.currentFilter.emptyViewConfig) { [viewModel] in
                                await viewModel.refreshFeed()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(48)
                        } else {
                            List {
                                ForEach(viewModel.feed.entries, id: \.id) { item in
                                    Knock.FeedNotificationRow(item: item) { buttonTapString in
                                        viewModel.feedItemButtonTapped(item: item, actionString: buttonTapString)
                                    }
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(theme.rowTheme.backgroundColor)
                                    .contentShape(Rectangle()) // Make the entire row tappable
                                    .background(self.selectedItemId == item.id ? Color.gray.opacity(0.4) : .clear)
                                    .animation(.easeInOut, value: self.selectedItemId)
                                    .onTapGesture {
                                        highlightTappedRow(id: item.id)
                                        viewModel.feedItemRowTapped(item: item)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        if let config = theme.rowTheme.archiveSwipeConfig {
                                            let useInverse = item.archived_at != nil
                                            Knock.SwipeButton(config: config, useInverse: useInverse) {
                                                viewModel.didSwipeRow(item: item, swipeAction: config.action, useInverse: useInverse)
                                            }
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        if let config = theme.rowTheme.markAsReadSwipeConfig {
                                            let useInverse = item.read_at != nil
                                            Knock.SwipeButton(config: config, useInverse: useInverse) {
                                                viewModel.didSwipeRow(item: item, swipeAction: config.action, useInverse: useInverse)
                                            }
                                        }
                                    }
                                }
                                
                                if viewModel.isMoreContentAvailable() {
                                    lastRowView()
                                }
                                
                                Spacer()
                                    .frame(height: 40)
                                    .listRowSeparator(.hidden)
                            }
                            .listStyle(PlainListStyle())
                            .refreshable { [viewModel] in
                                await viewModel.refreshFeed()
                            }
                        }
                    }
                    .background(theme.lowerBackgroundColor)
                    
                    if viewModel.brandingRequired {
                        KnockImages.poweredByKnockIcon
                            .shadow(radius: 3)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.refreshFeed()
                }
            }
            .onDisappear {
                Task {
                    await viewModel.bulkUpdateMessageEngagementStatus(updatedStatus: .seen)
                }
            }
        }
        
        private func highlightTappedRow(id: String) {
            selectedItemId = id
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                if selectedItemId == id {
                    selectedItemId = nil
                }
            }
        }
        
        @ViewBuilder
        private func topSectionView() -> some View {
            VStack(alignment: .leading, spacing: .zero) {
                if let title = theme.titleString {
                    Text(title)
                        .font(theme.titleFont)
                        .foregroundStyle(theme.titleColor)
                        .padding(.horizontal, 24)
                }
                
                if viewModel.filterOptions.count > 1 {
                    Knock.FilterBarView(filters: viewModel.filterOptions, selectedFilter: $viewModel.currentFilter)
                        .padding(.bottom, 12)
                }
                
                if let topButtons = viewModel.topButtonActions {
                    topActionButtonsView(topButtons: topButtons)
                        .padding(.bottom, 12)
                    Divider()
                }
            }
            .background(theme.upperBackgroundColor)
        }
        
        @ViewBuilder
        private func lastRowView() -> some View {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .contentShape(Rectangle())
            .listRowBackground(theme.rowTheme.backgroundColor)
            .frame(height: 50)
            .task { [viewModel] in
                await viewModel.fetchNewPageOfFeedItems()
            }
        }
        
        @ViewBuilder
        private func topActionButtonsView(topButtons: [Knock.FeedTopActionButtonType]) -> some View {
            HStack(alignment: .center, spacing: 12) {
                ForEach(topButtons, id: \.self) { action in
                    Knock.ActionButton(title: action.title, config: theme.rowTheme.tertiaryActionButtonConfig) {
                        Task {
                            await viewModel.topActionButtonTapped(action: action)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    let viewModel = Knock.InAppFeedViewModel()
    let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Alan Grant completed an activity.</p>")
    
    let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
    
    let items = (0..<9).map { index in
        Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "\(index)", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
    }
    viewModel.feed.entries = items
    
    return Knock.InAppFeedView(theme: Knock.InAppFeedTheme(titleString: "Notifications"))
        .environmentObject(viewModel)
}
