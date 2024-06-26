//
//  KnockFeedNotificationRow.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI
import WebKit


extension Knock {
    public struct FeedNotificationRow: View {
        public var item: Knock.FeedItem
        public var theme: FeedNotificationRowTheme = .init()
        public var buttonTapAction: (String) -> Void
        
        @State private var dynamicHeight: CGFloat = .zero
        
        private var isRead: Bool {
            return item.read_at != nil
        }
        
        public init(
            item: Knock.FeedItem,
            theme: FeedNotificationRowTheme = .init(),
            buttonTapAction: @escaping (String) -> Void
        ) {
            self.item = item
            self.theme = theme
            self.buttonTapAction = buttonTapAction
        }

        public var body: some View {
            VStack(spacing: .zero) {
                HStack(alignment: .top, spacing: 12) {
                    
                    HStack(alignment: .top, spacing: 0) {
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(isRead ? .clear : theme.unreadNotificationCircleColor)
                        
                        if theme.showAvatarView {
                            AvatarView(
                                imageURLString: item.actors?.first?.avatar,
                                name: item.actors?.first?.name,
                                backgroundColor: theme.avatarViewTheme.avatarViewBackgroundColor,
                                font: theme.avatarViewTheme.avatarViewInitialsFont,
                                textColor: theme.avatarViewTheme.avatarViewInitialsColor,
                                size: theme.avatarViewTheme.avatarViewSize
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: .zero) {
                        ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, block in
                            Group {
                                switch block {
                                case let block as Knock.MarkdownContentBlock:
                                    markdownContent(block: block)

                                case let block as Knock.ButtonSetContentBlock:
                                    actionButtonsContent(block: block)
                                        .padding(.bottom, 12)
                                default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        if let date = item.inserted_at {
                            Text(theme.sentAtDateFormatter.string(from: date))
                                .font(theme.sentAtDateFont)
                                .foregroundStyle(theme.sentAtDateTextColor)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.leading, 8)
                .padding(.trailing, 16)
                
                Divider()
                    .background(KnockColor.Gray.gray4)
            }
        }

        @ViewBuilder
        private func markdownContent(block: Knock.MarkdownContentBlock) -> some View {
            HtmlView(html: block.rendered)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        
        @ViewBuilder
        private func actionButtonsContent(block: Knock.ButtonSetContentBlock) -> some View {
            HStack {
                ForEach(Array(block.buttons.enumerated()), id: \.offset) { _, button in
                    ActionButton(
                        title: button.label,
                        config: button.name == "primary" ? theme.primaryActionButtonConfig : theme.secondaryActionButtonConfig
                    ) {}
                    .onTapGesture {
                        buttonTapAction(button.action)
                    }
                }
            }
        }
    }
}


struct FeedNotificationRow_Previews: PreviewProvider {
    static var previews: some View {
        let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Ian Malcolm completed an activity.</p>")
        
        let markdown2 = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Here's a new notification from <strong>Eleanor Price</strong>:</p><blockquote><p>test message test message test message test mtest message test message test message test message test messageessage test message test message test message test message test message test message test message </p></blockquote>")
                
        let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
        
        let item1 = Knock.FeedItem(__cursor: "", actors: [Knock.User(id: "1", name: "John Doe", email: nil, avatar: nil, phone_number: nil, properties: [:])], activities: [], blocks: [markdown], data: [:], id: "", inserted_at: Date(), interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        let item2 = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "", inserted_at: Date(), interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        let item3 = Knock.FeedItem(__cursor: "", actors: [Knock.User(id: "1", name: "John Doe", email: nil, avatar: nil, phone_number: nil, properties: [:])], activities: [], blocks: [markdown2], data: [:], id: "", inserted_at: Date(), interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        let item4 = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown2, buttons], data: [:], id: "", inserted_at: Date(), interacted_at: nil, clicked_at: nil, link_clicked_at: nil, archived_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        List {
            Knock.FeedNotificationRow(item: item1) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            Knock.FeedNotificationRow(item: item2) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            
            Knock.FeedNotificationRow(item: item3) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            Knock.FeedNotificationRow(item: item4) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())

    }
}
