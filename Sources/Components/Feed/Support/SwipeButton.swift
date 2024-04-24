//
//  SwipeButton.swift
//  
//
//  Created by Matt Gardner on 4/23/24.
//

import SwiftUI

extension Knock {
    struct SwipeButton: View {
        let config: SwipeButtonConfig
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                VStack(alignment: .center, spacing: 10) {
                    config.image
                    Text(config.title)
                        .font(config.titleFont)
                        .foregroundStyle(config.titleColor)
                }
            }
            .tint(config.swipeColor)
        }
    }

    public struct SwipeButtonConfig {
        public var action: Knock.FeedNotificationRowSwipeAction
        public var title: String
        public var titleFont: Font
        public var titleColor: Color
        public var image: Image
        public var swipeColor: Color
        public var showIcon: Bool
        
        public init(
            action: Knock.FeedNotificationRowSwipeAction,
            title: String? = nil,
            titleFont: Font? = nil,
            titleColor: Color? = nil,
            image: Image? = nil,
            swipeColor: Color? = nil,
            showIcon: Bool = true
        ) {
            self.action = action
            self.title = title ?? action.defaultTitle
            self.titleFont = titleFont ?? .knock2.weight(.medium)
            self.titleColor = titleColor ?? .white
            self.image = image ?? action.defaultImage
            self.swipeColor = swipeColor ?? action.defaultSwipeColor
            self.showIcon = showIcon
        }
    }
}
