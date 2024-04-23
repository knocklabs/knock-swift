//
//  SwipeButton.swift
//  
//
//  Created by Matt Gardner on 4/23/24.
//

import SwiftUI

struct SwipeButton: View {
    let config: SwipeButtonConfig
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                config.image
                Text(config.title)
                    .font(config.titleFont)
                    .foregroundStyle(config.titleColor)
            }
        }
        .tint(config.swipeColor)
    }
}

public struct SwipeButtonConfig {
    public var action: FeedNotificationRowSwipeAction
    public var title: String
    public var titleFont: Font
    public var titleColor: Color
    public var image: Image
    public var swipeColor: Color
    public var showIcon: Bool
    
    public init(
        action: FeedNotificationRowSwipeAction,
        title: String? = nil,
        titleFont: Font? = nil,
        titleColor: Color? = nil,
        image: Image? = nil,
        swipeColor: Color? = nil,
        showIcon: Bool = true
    ) {
        self.action = action
        self.title = title ?? action.defaultTitle
        self.titleFont = titleFont ?? .knock2.weight(.medium)
        self.titleColor = titleColor ?? .white
        self.image = image ?? action.defaultImage
        self.swipeColor = swipeColor ?? action.defaultSwipeColor
        self.showIcon = showIcon
    }
}

public enum FeedNotificationRowSwipeAction {
    case archive
    case markAsRead
    case markAsUnread
    
    public var defaultTitle: String {
        switch self {
        case .archive: return "Archive"
        case .markAsRead: return "Read"
        case .markAsUnread: return "Unread"
        }
    }
    
    public var defaultImage: Image {
        switch self {
        case .archive: return Image(systemName: "archivebox")
        case .markAsRead: return Image(systemName: "envelope.open")
        case .markAsUnread: return Image(systemName: "envelope")
        }
    }
    
    public var defaultSwipeColor: Color {
        switch self {
        case .archive: return KnockColor.Green.green9
        case .markAsRead: return KnockColor.Blue.blue9
        case .markAsUnread: return KnockColor.Blue.blue9
        }
    }
    
    public var defaultConfig: SwipeButtonConfig {
        return .init(action: self, title: defaultTitle, image: defaultImage, swipeColor: defaultSwipeColor)
    }
}
