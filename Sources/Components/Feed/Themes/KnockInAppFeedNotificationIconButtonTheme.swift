//
//  KnockInAppFeedNotificationIconButtonTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

struct KnockInAppFeedNotificationIconButtonTheme {
    var buttonImage: Image
    var buttonImageForeground: Color
    var buttonImageFont: Font
    var showBadgeWithCount: Bool
    var badgeCountFont: Font
    var badgeColor: Color
    var badgeCountColor: Color
    
    init(buttonImage: Image = Image(systemName: "bell"),
         buttonImageForeground: Color = .gray,
         buttonImageFont: Font = .title2,
         showBadgeWithCount: Bool = true,
         badgeCountFont: Font = .caption2,
         badgeColor: Color = .red,
         badgeCountColor: Color = .white
    ) {
        self.buttonImage = buttonImage
        self.buttonImageForeground = buttonImageForeground
        self.buttonImageFont = buttonImageFont
        self.showBadgeWithCount = showBadgeWithCount
        self.badgeCountFont = badgeCountFont
        self.badgeColor = badgeColor
        self.badgeCountColor = badgeCountColor
    }
}
