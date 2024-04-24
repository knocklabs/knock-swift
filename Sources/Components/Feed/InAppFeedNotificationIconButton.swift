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
        
        public init(theme: InAppFeedNotificationIconButtonTheme = InAppFeedNotificationIconButtonTheme(), action: @escaping () -> Void) {
            self.theme = theme
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                ZStack {
                    Image(systemName: (viewModel.unreadCount() > 0 && !theme.showBadgeWithCount) ? "bell.badge" : "bell")
                        .font(theme.buttonImageFont)
                        .foregroundColor(theme.buttonImageForeground)

                    if viewModel.unreadCount() > 0 && theme.showBadgeWithCount {
                        Text("\(viewModel.unreadCount())")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.badgeCountColor)
                            .frame(width: 10, height: 10)
                            .background(theme.badgeColor)
                            .clipShape(Circle())
                            .offset(x: 8, y: -10)
                    }
                }
            }
        }
    }
}

struct InAppFeedNotificationIconButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = Knock.InAppFeedViewModel()
        viewModel.feed.meta.unseenCount = 67
        
        return Knock.InAppFeedNotificationIconButton(action: {}).environmentObject(viewModel)
    }
}
