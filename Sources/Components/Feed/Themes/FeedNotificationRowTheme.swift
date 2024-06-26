//
//  FeedNotificationRowTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct FeedNotificationRowTheme {
        public var showAvatarView: Bool // Show or hide the avatar/initials view in the upper left corner of the row
        public var avatarViewTheme: AvatarViewTheme // Customize styling of avatarview
        public var notificationContentCSS: String? // Customize the css of the markdown html of the notification body
        public var backgroundColor: Color // Background color of the FeedNoticationRow
        public var markAsReadSwipeConfig: SwipeButtonConfig? // Set this to nil to remove the mark as read/unread swipe action
        public var archiveSwipeConfig: SwipeButtonConfig? // Set this to nil to remove the archive/unarchive swipe action
        public var unreadNotificationCircleColor: Color // Color of the unread circle indicator in the top left of the row
        public var sentAtDateFormatter: DateFormatter // DateFormatter for the sent timestamp at the bottom of the row
        public var sentAtDateFont: Font // Font for sent timestamp
        public var sentAtDateTextColor: Color // Color for sent timestamp
        public var primaryActionButtonConfig: ActionButtonConfig // Styling for primary action buttons
        public var secondaryActionButtonConfig: ActionButtonConfig // Styling for secondary action buttons
        public var tertiaryActionButtonConfig: ActionButtonConfig // Styling for tertiary action buttons
        
        public init(
            showAvatarView: Bool? = nil,
            avatarViewTheme: AvatarViewTheme? = nil,
            notificationContentCSS: String? = nil,
            backgroundColor: Color? = nil,
            markAsReadSwipeConfig: SwipeButtonConfig? = FeedNotificationRowSwipeAction.markAsRead.defaultConfig,
            archiveSwipeConfig: SwipeButtonConfig? = FeedNotificationRowSwipeAction.archive.defaultConfig,
            unreadNotificationCircleColor: Color? = nil,
            sentAtDateFormatter: DateFormatter? = nil,
            sentAtDateFont: Font? = nil,
            sentAtDateTextColor: Color? = nil,
            primaryActionButtonConfig: ActionButtonConfig? = nil,
            secondaryActionButtonConfig: ActionButtonConfig? = nil,
            tertiaryActionButtonConfig: ActionButtonConfig? = nil
        ) {
            self.showAvatarView = showAvatarView ?? true
            self.avatarViewTheme = avatarViewTheme ?? .init()
            self.notificationContentCSS = notificationContentCSS
            self.backgroundColor = backgroundColor ?? KnockColor.Surface.surface1
            self.markAsReadSwipeConfig = markAsReadSwipeConfig
            self.archiveSwipeConfig = archiveSwipeConfig
            self.unreadNotificationCircleColor = unreadNotificationCircleColor ?? KnockColor.Blue.blue9
            self.sentAtDateFormatter = sentAtDateFormatter ?? defaultDateFormatter
            self.sentAtDateFont = sentAtDateFont ?? .knock2.weight(.medium)
            self.sentAtDateTextColor = sentAtDateTextColor ?? KnockColor.Gray.gray9
            self.primaryActionButtonConfig = primaryActionButtonConfig ?? ActionButton.Style.primary.defaultConfig
            self.secondaryActionButtonConfig = secondaryActionButtonConfig ?? ActionButton.Style.secondary.defaultConfig
            self.tertiaryActionButtonConfig = tertiaryActionButtonConfig ?? ActionButton.Style.tertiary.defaultConfig
        }
        
        private var defaultDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter
        }()
    }
}
