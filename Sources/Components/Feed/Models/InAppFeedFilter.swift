//
//  InAppFeedFilter.swift
//
//
//  Created by Matt Gardner on 4/24/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct InAppFeedFilter: Hashable {
        public var scope: Knock.FeedItemScope
        public var title: String
        public var emptyViewConfig: EmptyFeedViewConfig
        
        public init(scope: Knock.FeedItemScope, title: String? = nil, emptyViewConfig: EmptyFeedViewConfig? = nil) {
            self.scope = scope
            self.title = title ?? scope.rawValue.capitalized
            self.emptyViewConfig = emptyViewConfig ?? InAppFeedFilter.defaultEmptyViewConfig(scope: scope)
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
        
        public static func == (lhs: InAppFeedFilter, rhs: InAppFeedFilter) -> Bool {
            return lhs.scope == rhs.scope
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(scope)
        }
    }
}
