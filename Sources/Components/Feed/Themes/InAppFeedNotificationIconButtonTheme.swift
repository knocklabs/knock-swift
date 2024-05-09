//
//  KnockInAppFeedNotificationIconButtonTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct InAppFeedNotificationIconButtonTheme {
        public var buttonImage: Image
        public var buttonImageForeground: Color
        public var buttonImageSize: CGSize
        public var showBadgeWithCount: Bool
        public var badgeCountFont: Font
        public var badgeColor: Color
        public var badgeCountColor: Color
        public var notificationCountType: ReadStatusType
        
        public init(
            buttonImage: Image? = nil,
            buttonImageForeground: Color? = nil,
            buttonImageSize: CGSize? = nil,
            showBadgeWithCount: Bool? = nil,
            badgeCountFont: Font? = nil,
            badgeColor: Color? = nil,
            badgeCountColor: Color? = nil,
            notificationCountType: ReadStatusType? = nil
        ) {
            self.buttonImage = buttonImage ?? Image(systemName: "bell")
            self.buttonImageForeground = buttonImageForeground ?? KnockColor.Gray.gray12
            self.buttonImageSize = buttonImageSize ?? .init(width: 24, height: 24)
            self.showBadgeWithCount = showBadgeWithCount ?? true
            self.badgeCountFont = badgeCountFont ?? .knock0.weight(.medium)
            self.badgeColor = badgeColor ?? KnockColor.Accent.accent9
            self.badgeCountColor = badgeCountColor ?? .white
            self.notificationCountType = notificationCountType ?? .unread
        }
    }
        
    public enum ReadStatusType {
        case unread
        case unseen
    }
}
