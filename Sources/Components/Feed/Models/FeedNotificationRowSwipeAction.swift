//
//  FeedNotificationRowSwipeAction.swift
//
//
//  Created by Matt Gardner on 4/24/24.
//

import Foundation
import SwiftUI

extension Knock {
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
}
