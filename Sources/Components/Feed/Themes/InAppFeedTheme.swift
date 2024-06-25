//
//  KnockInAppFeedTheme.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct InAppFeedTheme {
        public var rowTheme: FeedNotificationRowTheme = .init()
        public var filterBarTheme: FilterBarTheme = FilterBarTheme()
        
        public var titleString: String?
        public var titleFont: Font
        public var titleColor: Color

        public var upperBackgroundColor: Color
        public var lowerBackgroundColor: Color
        
        public init(
            rowTheme: FeedNotificationRowTheme = .init(),
            titleString: String? = "Notifications",
            titleFont: Font? = nil,
            titleColor: Color? = nil,
            upperBackgroundColor: Color? = nil,
            lowerBackgroundColor: Color? = nil
        ) {
            self.rowTheme = rowTheme
            self.titleString = titleString
            self.titleFont = titleFont ?? Font.knock8.bold()
            self.titleColor = titleColor ?? KnockColor.Gray.gray12
            self.upperBackgroundColor = upperBackgroundColor ?? KnockColor.Surface.surface1
            self.lowerBackgroundColor = lowerBackgroundColor ?? KnockColor.Surface.surface1
        }
    }
}
