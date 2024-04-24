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
        public var buttonImageFont: Font
        public var showBadgeWithCount: Bool
        public var badgeCountFont: Font
        public var badgeColor: Color
        public var badgeCountColor: Color
        
        public init(buttonImage: Image = Image(systemName: "bell"),
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
}
