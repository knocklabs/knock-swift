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
            getBellIcon(unseenCount: viewModel.feed.meta.unseen_count)
        }
    }
    
    @ViewBuilder
    private func getBellIcon(unseenCount: Int) -> some View {
        ZStack {
            Image(systemName: (unseenCount > 0 && !theme.showBadgeWithCount) ? "bell.badge" : "bell")
                .font(theme.buttonImageFont)
                .foregroundColor(theme.buttonImageForeground) // Use foregroundColor for consistency

            if unseenCount > 0 && theme.showBadgeWithCount {
                // Position the badge number at the top-right of the bell icon
                Text("\(unseenCount)")
                    .font(.caption2) // Smaller font size for the count
                    .fontWeight(.bold)
                    .foregroundColor(theme.badgeCountColor)
                    .frame(width: 15, height: 15)
                    .background(theme.badgeColor)
                    .clipShape(Circle())
                    .offset(x: 8, y: -10)
            }
        }
    }
}

struct KnockInAppFeedNotificationIconButton_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = KnockInAppFeedViewModel()
        viewModel.feed.meta.unseen_count = 3
        
        return KnockInAppFeedNotificationIconButton(action: {}).environmentObject(viewModel)
    }
}
