//
//  AvatarViewTheme.swift
//
//
//  Created by Matt Gardner on 4/24/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct AvatarViewTheme {
        public var avatarViewBackgroundColor: Color
        public var avatarViewInitialsFont: Font
        public var avatarViewInitialsColor: Color
        public var avatarViewSize: CGFloat
        
        public init(
            avatarViewBackgroundColor: Color? = nil,
            avatarViewInitialsFont: Font? = nil,
            avatarViewInitialsColor: Color? = nil,
            avatarViewSize: CGFloat? = nil
        ) {
            self.avatarViewBackgroundColor = avatarViewBackgroundColor ?? KnockColor.Gray.gray5
            self.avatarViewInitialsFont = avatarViewInitialsFont ?? .knock1.weight(.medium)
            self.avatarViewInitialsColor = avatarViewInitialsColor ?? KnockColor.Gray.gray11
            self.avatarViewSize = avatarViewSize ?? 32
        }
    }
}
