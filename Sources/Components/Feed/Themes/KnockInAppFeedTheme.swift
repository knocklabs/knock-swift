//
//  KnockInAppFeedTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

struct KnockInAppFeedTheme {
    var rowTheme: FeedNotificationRowTheme = .init()
    
    var titleString: String = "Notifications"
    var titleFont: Font = Font.title
    var titleColor: Color = .primary
    
    var emptyViewTitle: String? = "No notifcations yet"
    var emptyViewTitleFont: Font = Font.title
    var emptyViewTitleColor: Color = .primary

    var emptyViewSubtitle: String? = "We'll let you know when we've got something new for you."
    var emptyViewSubtitleFont: Font = Font.body
    var emptyViewSubtitleColor: Color = .primary

    var upperBackgroundColor: Color = .white
    var lowerBackgroundColor: Color = .white
}
