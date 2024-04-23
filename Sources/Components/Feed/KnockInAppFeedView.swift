//
//  KnockInAppFeedView.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

public struct KnockInAppFeedView: View {
    @EnvironmentObject public var viewModel: KnockInAppFeedViewModel
    public var theme: KnockInAppFeedTheme = .init()
    
    public init(theme: KnockInAppFeedTheme = .init()) {
        self.theme = theme
    }
    @State private var selectedItemId: String? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            VStack(alignment: .leading, spacing: .zero) {
                if let title = theme.titleString {
                    Text(title)
                        .font(theme.titleFont)
                        .foregroundStyle(theme.titleColor)
                        .padding(.horizontal, 24)
                }
                
                if viewModel.filterOptions.count > 1 {
                    filterTabView()
                        .padding(.bottom, 12)
                }
                
                if !viewModel.topButtonActions.isEmpty {
                    topActionButtonsView()
                        .padding(.bottom, 12)
                    Divider()
                }
            }
            .background(theme.upperBackgroundColor)
            
            Group {
                if viewModel.feed.entries.isEmpty {
                    EmptyFeedView(config: viewModel.currentFilter.emptyViewConfig) {
                        Task {
                            await viewModel.refreshFeed()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(48)
                    
                } else {
                    List {
                        ForEach(viewModel.feed.entries, id: \.id) { item in
                            KnockFeedNotificationRow(item: item, isRead: viewModel.itemIsSeen(item: item), theme: .init()) { buttonTapString in
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
                                if let config = theme.rowTheme.swipeLeftConfig {
                                    SwipeButton(config: config) {
                                        viewModel.didSwipeRow(item: item, swipeAction: config.action)
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if let config = theme.rowTheme.swipeRightConfig {
                                    SwipeButton(config: config) {
                                        viewModel.didSwipeRow(item: item, swipeAction: config.action)
                                    }
                                }
                            }
                        }
                        
                        if viewModel.isMoreContentAvailable() {
                            lastRowView()
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refreshFeed()
                    }
                }
            }
            .background(theme.lowerBackgroundColor)
        }
        .task {
            await viewModel.refreshFeed()
        }
        .onDisappear {
            if viewModel.markAllAsReadOnClose {
                Task {
                    await viewModel.markAllAsRead()
                }
            }
        }
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
        .padding(.bottom, 24)
        .task {
            await viewModel.fetchNewPageOfFeedItems()
        }
    }
    
    @ViewBuilder
    private func filterTabView() -> some View {
        ZStack(alignment: .bottom) {
            Divider()
                .frame(height: 1)
                .background(KnockColor.Gray.gray4)

            HStack(spacing: .zero
            ) {
                ForEach(viewModel.filterOptions, id: \.self) { option in
                    Text(option.title)
                        .font(.knock2.weight(.medium))
                        .foregroundColor(option == viewModel.currentFilter ? KnockColor.Accent.accent11 : KnockColor.Gray.gray11)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(option == viewModel.currentFilter ? KnockColor.Accent.accent9 : .clear),
                            alignment: .bottom
                        )
                        .onTapGesture {
                            withAnimation {
                                viewModel.currentFilter = option
                            }
                        }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        
    }
    
    @ViewBuilder
    private func topActionButtonsView() -> some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(viewModel.topButtonActions, id: \.self) { option in
                ActionButton(title: option.title, config: theme.rowTheme.tertiaryActionButtonConfig) {
                    
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct KnockInAppFeedView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = KnockInAppFeedViewModel()        
        let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Alan Grant completed an activity.</p>")
                
        let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
        
        let item = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        viewModel.feed.entries = [item, item, item, item]
        viewModel.feed.entries = []
        
        let theme = KnockInAppFeedTheme(titleString: "Notifications")
        
        return KnockInAppFeedView(theme: theme)
            .environmentObject(viewModel)
    }
}
