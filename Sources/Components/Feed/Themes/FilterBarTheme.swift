//
//  FilterBarTheme.swift
//
//
//  Created by Matt Gardner on 6/24/24.
//

import Foundation
import SwiftUI

extension Knock {
    public struct FilterBarTheme {
        public var selectedColor: Color?
        public var unselectedColor: Color?
        public var font: Font?
        public var fontColor: Color?
        
        public init(
            selectedColor: Color? = nil,
            unselectedColor: Color? = nil,
            font: Font? = nil,
            avatarViewSize: Color? = nil
        ) {
            self.selectedColor = selectedColor ?? KnockColor.Accent.accent11
            self.unselectedColor = unselectedColor ?? KnockColor.Gray.gray11
            self.font = font ?? .knock2.weight(.medium)
            self.fontColor = fontColor ?? KnockColor.Accent.accent11
        }
    }
}
