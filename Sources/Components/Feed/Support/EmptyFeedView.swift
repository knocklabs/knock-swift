//
//  EmptyFeedView.swift
//
//
//  Created by Matt Gardner on 4/23/24.
//

import SwiftUI

struct EmptyFeedView: View {
    let config: EmptyFeedViewConfig
    let refreshAction: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                if let image = config.icon {
                    image
                }
                
                if let title = config.title {
                    Text(title)
                        .font(config.titleFont)
                        .foregroundStyle(config.titleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 170)
                }
                
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(config.subtitleFont)
                        .foregroundStyle(config.subtitleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 170)
                }
       
                Spacer()
            }
        }
        .refreshable {
            refreshAction()
        }
    }
}

public struct EmptyFeedViewConfig {
    public let title: String?
    public let titleFont: Font
    public let titleColor: Color
    public let subtitle: String?
    public let subtitleFont: Font
    public let subtitleColor: Color
    public let icon: Image?
    
    public init(
        title: String? = nil,
        titleFont: Font? = nil,
        titleColor: Color? = nil,
        subtitle: String? = nil,
        subtitleFont: Font? = nil,
        subtitleColor: Color? = nil,
        icon: Image? = nil
    ) {
        self.title = title
        self.titleFont = titleFont ?? .knock2.weight(.medium)
        self.titleColor = titleColor ?? KnockColor.Gray.gray12
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont ?? .knock2
        self.subtitleColor = subtitleColor ?? KnockColor.Gray.gray12
        self.icon = icon
    }
}

public struct KnockInAppFeedFilter: Hashable {
    public var scope: Knock.FeedItemScope
    public var title: String
    public var emptyViewConfig: EmptyFeedViewConfig
    
    public init(scope: Knock.FeedItemScope, title: String? = nil, emptyViewConfig: EmptyFeedViewConfig? = nil) {
        self.scope = scope
        self.title = title ?? scope.rawValue.capitalized
        self.emptyViewConfig = emptyViewConfig ?? KnockInAppFeedFilter.defaultEmptyViewConfig(scope: scope)
    }
    
    private static func defaultEmptyViewConfig(scope: Knock.FeedItemScope) -> EmptyFeedViewConfig {
        switch scope {
        case .archived:
            return EmptyFeedViewConfig(title: "No archived messages", subtitle: "Any notifications you archive will show up here", icon: Image(systemName: "tray"))
        case .all:
            return EmptyFeedViewConfig(title: "All caught up", subtitle: "You’ll see previously read and new notifications here", icon: Image(systemName: "tray"))
        case .unread:
            return EmptyFeedViewConfig(title: "No unread messages", subtitle: "Any notifications you haven't read show up here", icon: Image(systemName: "tray"))
        case .unseen:
            return EmptyFeedViewConfig(title: "No unseen messages", subtitle: "Any notifications you haven't seen will show up here", icon: Image(systemName: "tray"))
        default: return EmptyFeedViewConfig(title: "No messages", subtitle: "We'll let you know when we've got something new for you.", icon: Image(systemName: "tray"))
        }
    }
    
    public static func == (lhs: KnockInAppFeedFilter, rhs: KnockInAppFeedFilter) -> Bool {
        return lhs.scope == rhs.scope
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(scope)
    }
}

#Preview {
    let filter = KnockInAppFeedFilter(scope: .archived)
    return EmptyFeedView(config: filter.emptyViewConfig) {}
}
