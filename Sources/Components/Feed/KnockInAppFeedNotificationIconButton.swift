//
//  KnockInAppFeedViewModel.swift
//
//
//  Created by Matt Gardner on 4/12/24.
//

import SwiftUI

public struct KnockInAppFeedNotificationIconButton: View {
    @EnvironmentObject public var viewModel: KnockInAppFeedViewModel
    public var theme = KnockInAppFeedNotificationIconButtonTheme()
    public var action: () -> Void
    
    public init(theme: KnockInAppFeedNotificationIconButtonTheme = KnockInAppFeedNotificationIconButtonTheme(), action: @escaping () -> Void) {
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

struct KnockInAppFeedNotificationIconButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = KnockInAppFeedViewModel()
        viewModel.feed.meta.unseenCount = 67
        
        return KnockInAppFeedNotificationIconButton(action: {}).environmentObject(viewModel)
    }
}
