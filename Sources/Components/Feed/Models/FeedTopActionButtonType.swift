//
//  FeedTopActionButtonType.swift
//  
//
//  Created by Matt Gardner on 4/24/24.
//

import Foundation

extension Knock {
    public enum FeedTopActionButtonType: Hashable {
        case markAllAsRead(title: String = "Mark all as read")
        case archiveRead(title: String = "Archive read")
        case archiveAll(title: String = "Archive all")
        
        var title: String {
                switch self {
                case .markAllAsRead(let title),
                     .archiveRead(let title),
                     .archiveAll(let title):
                    return title
                }
            }
    }
}
