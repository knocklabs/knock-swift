//
//  KnockInAppFeedTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

public struct KnockInAppFeedTheme {
    public var rowTheme: FeedNotificationRowTheme = .init()
    
    public var titleString: String = "Notifications"
    public var titleFont: Font = Font.title
    public var titleColor: Color = .primary
    
    public var emptyViewTitle: String? = "No notifcations yet"
    public var emptyViewTitleFont: Font = Font.title
    public var emptyViewTitleColor: Color = .primary

    public var emptyViewSubtitle: String? = "We'll let you know when we've got something new for you."
    public var emptyViewSubtitleFont: Font = Font.body
    public var emptyViewSubtitleColor: Color = .primary

    public var upperBackgroundColor: Color = .white
    public var lowerBackgroundColor: Color = .white
    
    public init(
        rowTheme: FeedNotificationRowTheme = .init(),
        titleString: String = "Notifications",
        titleFont: Font = Font.title,
        titleColor: Color = .primary,
        emptyViewTitle: String? = "No notifications yet",
        emptyViewTitleFont: Font = Font.title,
        emptyViewTitleColor: Color = .primary,
        emptyViewSubtitle: String? = "We'll let you know when we've got something new for you.",
        emptyViewSubtitleFont: Font = Font.body,
        emptyViewSubtitleColor: Color = .primary,
        upperBackgroundColor: Color = .white,
        lowerBackgroundColor: Color = .white
    ) {
        self.rowTheme = rowTheme
        self.titleString = titleString
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.emptyViewTitle = emptyViewTitle
        self.emptyViewTitleFont = emptyViewTitleFont
        self.emptyViewTitleColor = emptyViewTitleColor
        self.emptyViewSubtitle = emptyViewSubtitle
        self.emptyViewSubtitleFont = emptyViewSubtitleFont
        self.emptyViewSubtitleColor = emptyViewSubtitleColor
        self.upperBackgroundColor = upperBackgroundColor
        self.lowerBackgroundColor = lowerBackgroundColor
    }
}
