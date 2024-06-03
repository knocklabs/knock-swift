//
//  InAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

extension Knock {
    public struct InAppFeedNotificationIconButton: View {
        @EnvironmentObject public var viewModel: InAppFeedViewModel
        public var theme = InAppFeedNotificationIconButtonTheme() // Defines the appearance of the feed view and its components.
        public var action: () -> Void // A callback to alert you when user taps on the button.
        
        private var countText: String {
            let count = theme.notificationCountType == .unread ? viewModel.feed.meta.unreadCount : viewModel.feed.meta.unseenCount
            guard theme.showBadgeWithCount, count > 0 else { return "" }
            return count > 99 ? "99" : "\(count)"
        }
        
        private var showUnreadBadge: Bool {
            theme.notificationCountType == .unread ? viewModel.feed.meta.unreadCount > 0 : viewModel.feed.meta.unseenCount > 0
        }
        
        private var badgePadding: CGFloat {
            return countText.count > 1 ? 4 : 6
        }
        
        public init(theme: InAppFeedNotificationIconButtonTheme = InAppFeedNotificationIconButtonTheme(), action: @escaping () -> Void) {
            self.theme = theme
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                ZStack {
                    Image(systemName: "bell")
                        .resizable()
                        .frame(width: theme.buttonImageSize.width, height: theme.buttonImageSize.height)
                        .foregroundColor(theme.buttonImageForeground)
                    
                    if showUnreadBadge {
                        Text(countText)
                            .font(theme.badgeCountFont)
                            .padding(badgePadding)
                            .foregroundColor(theme.badgeCountColor)
                            .background(theme.badgeColor)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
            }
        }
    }
}

struct InAppFeedNotificationIconButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = Knock.InAppFeedViewModel()
        viewModel.feed.meta.unreadCount = 9
        
        return Knock.InAppFeedNotificationIconButton(action: {}).environmentObject(viewModel)
    }
}
