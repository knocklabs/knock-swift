//
//  FeedNotificationRowTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

public struct FeedNotificationRowTheme {
    public var showAvatarView: Bool = true
    public var htmlFont: String = "-apple-system, sans-serif"
    public var htmlFontSize: Int = 20
    public var backgroundColor: Color = .clear
    public var swipeRightConfig: FeedNotificationRowSwipeConfig? = .init(action: .archive)
    public var swipeLeftConfig: FeedNotificationRowSwipeConfig? = .init(action: .markAsRead)
    
    public init(
        showAvatarView: Bool = true,
        htmlFont: String = "-apple-system, sans-serif",
        htmlFontSize: Int = 20,
        backgroundColor: Color = .clear,
        swipeRightConfig: FeedNotificationRowSwipeConfig? = .init(action: .archive),
        swipeLeftConfig: FeedNotificationRowSwipeConfig? = .init(action: .markAsRead)
    ) {
        self.showAvatarView = showAvatarView
        self.htmlFont = htmlFont
        self.htmlFontSize = htmlFontSize
        self.backgroundColor = backgroundColor
        self.swipeRightConfig = swipeRightConfig
        self.swipeLeftConfig = swipeLeftConfig
    }
}

public enum FeedNotificationRowSwipeAction {
    case archive
    case markAsRead
    case markAsSeen
    
    public var defaultTitle: String {
        switch self {
        case .archive: return "Archive"
        case .markAsRead: return "Mark As Read"
        case .markAsSeen: return "Mark As Seen"
        }
    }
    
    public var defaultSystemImage: String {
        switch self {
        case .archive: return "trash"
        case .markAsRead: return "eye"
        case .markAsSeen: return "eye"
        }
    }
    
    public var defaultSwipeColor: Color {
        switch self {
        case .archive: return .red
        case .markAsRead: return .blue
        case .markAsSeen: return .blue
        }
    }
}

public struct FeedNotificationRowSwipeConfig {
    public var action: FeedNotificationRowSwipeAction
    public var title: String
    public var systemImage: String
    public var swipeColor: Color
    public var showIcon: Bool
    
    public init(
        action: FeedNotificationRowSwipeAction,
        title: String? = nil,
        systemImage: String? = nil,
        swipeColor: Color? = nil,
        showIcon: Bool = true
    ) {
        self.action = action
        self.title = title ?? action.defaultTitle
        self.systemImage = systemImage ?? action.defaultSystemImage
        self.swipeColor = swipeColor ?? action.defaultSwipeColor
        self.showIcon = showIcon
    }
}
