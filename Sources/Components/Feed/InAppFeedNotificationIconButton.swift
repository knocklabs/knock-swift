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
        public var theme = InAppFeedNotificationIconButtonTheme()
        public var action: () -> Void
        
        private var countText: String {
            let count = theme.notificationCountType == .unread ? viewModel.feed.meta.unreadCount : viewModel.feed.meta.unseenCount
            guard theme.showBadgeWithCount, count > 0 else { return "" }
            return count > 99 ? "99" : "\(count)"
        }
        
        public init(theme: InAppFeedNotificationIconButtonTheme = InAppFeedNotificationIconButtonTheme(), action: @escaping () -> Void) {
            self.theme = theme
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                ZStack {
                    Image(systemName: "bell")
                        .font(theme.buttonImageFont)
                        .foregroundColor(theme.buttonImageForeground)
                    
                    Text(countText)
                        .font(.knock0.weight(.medium))
                        .foregroundColor(theme.badgeCountColor)
                        .frame(width: 20, height: 20)
                        .background(theme.badgeColor)
                        .clipShape(Circle())
                        .offset(x: 10, y: -10)
                }
            }
        }
    }
}

struct InAppFeedNotificationIconButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = Knock.InAppFeedViewModel()
        viewModel.feed.meta.unreadCount = 1
        
        return Knock.InAppFeedNotificationIconButton(action: {}).environmentObject(viewModel)
    }
}
