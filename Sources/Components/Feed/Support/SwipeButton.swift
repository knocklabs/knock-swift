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
        let useInverse: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .center, spacing: 10) {
                    if useInverse {
                        config.inverseImage
                    } else {
                        config.image
                    }
                    Text(useInverse ? config.inverseTitle : config.title)
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
        public var inverseTitle: String
        public var titleFont: Font
        public var titleColor: Color
        public var image: Image
        public var inverseImage: Image
        public var swipeColor: Color
        public var showIcon: Bool
        
        public init(
            action: Knock.FeedNotificationRowSwipeAction,
            title: String? = nil,
            inverseTitle: String? = nil,
            titleFont: Font? = nil,
            titleColor: Color? = nil,
            image: Image? = nil,
            inverseImage: Image? = nil,
            swipeColor: Color? = nil,
            showIcon: Bool = true
        ) {
            self.action = action
            self.title = title ?? action.defaultTitle
            self.inverseTitle = inverseTitle ?? action.defaultInverseTitle
            self.titleFont = titleFont ?? .knock2.weight(.medium)
            self.titleColor = titleColor ?? .white
            self.image = image ?? action.defaultImage
            self.inverseImage = inverseImage ?? action.defaultInverseImage
            self.swipeColor = swipeColor ?? action.defaultSwipeColor
            self.showIcon = showIcon
        }
    }
}
