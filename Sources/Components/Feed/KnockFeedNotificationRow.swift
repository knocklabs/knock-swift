//
//  KnockFeedNotificationRow.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

public struct KnockFeedNotificationRow: View {
    public var item: Knock.FeedItem
    public var theme: FeedNotificationRowTheme = .init()
    public var buttonTapAction: (String) -> Void
    
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
        VStack() {
            HStack(alignment: .top) {
                if theme.showAvatarView {
                    AvatarView(imageURLString: item.actors?.first?.avatar, name: item.actors?.first?.name)
                }
                
                VStack(alignment: .leading, spacing: .zero) {
                    ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, block in
                        Group {
                            switch block {
                            case let block as Knock.MarkdownContentBlock:
                                markdownContent(block: block)
                            case let block as Knock.ButtonSetContentBlock:
                                actionButtonsContent(block: block)
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding()
            
            Divider()
        }
    }

    @ViewBuilder
    private func markdownContent(block: Knock.MarkdownContentBlock) -> some View {
        let cssString = """
            <style>
            body {
              font-family: \(theme.htmlFont);
              font-size: \(theme.htmlFontSize);
            }
            </style>
        """
        let htmlString = "\(cssString)\(block.rendered)"
                
        HtmlView(html: htmlString)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func actionButtonsContent(block: Knock.ButtonSetContentBlock) -> some View {
        HStack {
            ForEach(Array(block.buttons.enumerated()), id: \.offset) { _, button in
                actionButton(button: button)
            }
        }
    }
    
    @ViewBuilder
    private func actionButton(button: Knock.BlockActionButton) -> some View {
        let isPrimary = button.name == "primary"
        Button(button.label, action: {})
            .foregroundStyle(isPrimary ? .white : .black)
            .padding(8)
            .background(isPrimary ? .red : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.gray, lineWidth: isPrimary ? 0 : 1)
            )
            .onTapGesture {
                buttonTapAction(button.action)
            }
    }
}

struct FeedNotificationRow_Previews: PreviewProvider {
    static var previews: some View {
        let markdown = Knock.MarkdownContentBlock(name: "markdown", content: "", rendered: "<p>Hey <strong>Dennis</strong> 👋 - Alan Grant completed an activity.</p>")
                
        let buttons = Knock.ButtonSetContentBlock(name: "buttons", buttons: [Knock.BlockActionButton(label: "Primary", name: "primary", action: ""), Knock.BlockActionButton(label: "Secondary", name: "secondary", action: "")])
        
        let item = Knock.FeedItem(__cursor: "", actors: [], activities: [], blocks: [markdown, buttons], data: [:], id: "", inserted_at: nil, interacted_at: nil, clicked_at: nil, link_clicked_at: nil, total_activities: 0, total_actors: 0, updated_at: nil)
        
        
        List {
            KnockFeedNotificationRow(item: item, theme: .init()) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            KnockFeedNotificationRow(item: item, theme: .init()) { _ in }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())

    }
}
