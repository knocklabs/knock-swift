//
//  FeedNotificationRowTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

struct FeedNotificationRowTheme {
    var showAvatarView: Bool = true
    var htmlFont: String = "-apple-system, sans-serif"
    var htmlFontSize: Int = 20
    var backgroundColor: Color = .clear
    var swipeRightConfig: FeedNotificationRowSwipeConfig? = .init(action: .archive)
    var swipeLeftConfig: FeedNotificationRowSwipeConfig? = .init(action: .markAsRead)
}

enum FeedNotificationRowSwipeAction {
    case archive
    case markAsRead
    case markAsSeen
    
    var defaultTitle: String {
        switch self {
        case .archive: return "Archive"
        case .markAsRead: return "Mark As Read"
        case .markAsSeen: return "Mark As Seen"
        }
    }
    
    var defaultSystemImage: String {
        switch self {
        case .archive: return "trash"
        case .markAsRead: return "eye"
        case .markAsSeen: return "eye"
        }
    }
    
    var defaultSwipeColor: Color {
        switch self {
        case .archive: return .red
        case .markAsRead: return .blue
        case .markAsSeen: return .blue
        }
    }
}

struct FeedNotificationRowSwipeConfig {
    var action: FeedNotificationRowSwipeAction
    var title: String
    var systemImage: String
    var swipeColor: Color
    var showIcon: Bool
    
    init(action: FeedNotificationRowSwipeAction, title: String? = nil, systemImage: String? = nil, swipeColor: Color? = nil, showIcon: Bool = true) {
        self.action = action
        self.title = title ?? action.defaultTitle
        self.systemImage = systemImage ?? action.defaultSystemImage
        self.swipeColor = swipeColor ?? action.defaultSwipeColor
        self.showIcon = showIcon
    }
}
