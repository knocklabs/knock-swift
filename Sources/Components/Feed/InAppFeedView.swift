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
                            Knock.EmptyFeedView(config: viewModel.currentFilter.emptyViewConfig) {
                                Task {
                                    await viewModel.refreshFeed()
                                }
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
                                        self.selectedItemId = item.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            self.selectedItemId = nil
                                        }
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
                            .refreshable {
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
            .task {
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

struct InAppFeedView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = Knock.InAppFeedViewModel()
        let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Alan Grant completed an activity.</p>")
                
        let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
        
        let item = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        viewModel.feed.entries = [item, item, item, item, item, item, item, item, item]
        let theme = Knock.InAppFeedTheme(titleString: "Notifications")
        
        return Knock.InAppFeedView(theme: theme)
            .environmentObject(viewModel)
    }
}
