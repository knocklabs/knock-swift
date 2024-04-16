//
//  KnockInAppFeedView.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

struct KnockInAppFeedView: View {
    @EnvironmentObject var viewModel: KnockInAppFeedViewModel
    var theme: KnockInAppFeedTheme = .init()
    
    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            VStack(alignment: .leading, spacing: 15) {
                Text(theme.titleString)
                    .font(theme.titleFont)
                    .foregroundStyle(theme.titleColor)
                    .padding(.horizontal, 24)
                
                if viewModel.filterOptions.count > 1 {
                    Picker("Filter", selection: $viewModel.currentFilter) {
                        ForEach(viewModel.filterOptions, id: \.self) { filter in
                            Text(filter.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 24)
                }
                Divider()
            }
            .background(theme.upperBackgroundColor)
            
            
            Group {
                if viewModel.feed.entries.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        
                        if let title = theme.emptyViewTitle {
                            Text(title)
                                .font(theme.emptyViewTitleFont)
                                .foregroundStyle(theme.emptyViewTitleColor)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let subtitle = theme.emptyViewSubtitle {
                            Text(subtitle)
                                .font(theme.emptyViewSubtitleFont)
                                .foregroundStyle(theme.emptyViewSubtitleColor)
                                .multilineTextAlignment(.center)
                        }
               
                        Spacer()
                    }
                    .padding(24)
                    
                } else {
                    List {
                        ForEach(viewModel.feed.entries, id: \.id) { item in
                            FeedNotificationRow(item: item, theme: .init()) { buttonTapString in
                                print("didTapRowButton")
                                viewModel.feedItemButtonTapped(item: item, actionString: buttonTapString)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle()) // Make the entire row tappable
                            .onTapGesture {
                                print("Row tapped")
                                viewModel.feedItemRowTapped(item: item)
                            }
                            .listRowBackground(theme.rowTheme.backgroundColor)
                            .swipeActions(edge: .trailing) {
                                if let config = theme.rowTheme.swipeLeftConfig {
                                    swipeButton(item: item, config: config)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if let config = theme.rowTheme.swipeRightConfig {
                                    swipeButton(item: item, config: config)
                                }
                            }
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
        .onDisappear {
            Task {
                await viewModel.markAllAsSeen()
            }
        }
    }
    
    @ViewBuilder
    private func swipeButton(item: Knock.FeedItem, config: FeedNotificationRowSwipeConfig) -> some View {
        Button {
            viewModel.didSwipeRow(item: item, swipeAction: config.action)
        } label: {
            Label(config.title, systemImage: config.showIcon ? config.systemImage : "")
        }
        .tint(config.swipeColor)
    }
}

struct KnockInAppFeedView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = KnockInAppFeedViewModel()
        viewModel.feed.meta.unseen_count = 3
        
        let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Alan Grant completed an activity.</p>")
                
        let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
        
        let item = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        viewModel.feed.entries = [item, item, item, item]
        
        return KnockInAppFeedView().environmentObject(viewModel)
    }
}
