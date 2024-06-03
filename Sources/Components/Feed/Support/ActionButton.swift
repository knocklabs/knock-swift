//
//  ActionButton.swift
//
//
//  Created by Matt Gardner on 4/19/24.
//

import SwiftUI

extension Knock {
    struct ActionButton: View {
        let title: String
        let config: ActionButtonConfig
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(config.font)
                    .foregroundStyle(config.textColor)
                    .padding(.vertical, 8)
                    .frame(maxWidth: config.fillAvailableSpace ? .infinity : .none)
                    .padding(.horizontal, 12)

            }
            .background(config.backgroundColor)
            .cornerRadius(config.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(config.borderColor, lineWidth: config.borderWidth)
                )

        }
        
        enum Style {
            case primary
            case secondary
            case tertiary
            
            var defaultConfig: ActionButtonConfig {
                switch self {
                case .primary: return ActionButtonConfig(textColor: .white, backgroundColor: KnockColor.Accent.accent9, borderWidth: 0)
                default: return ActionButtonConfig(textColor: KnockColor.Gray.gray12, backgroundColor: .clear, fillAvailableSpace: self == .tertiary)
                }
            }
        }
    }
    
    public struct ActionButtonConfig {
        public let font: Font
        public let textColor: Color
        public let backgroundColor: Color
        public let borderWidth: CGFloat
        public let borderColor: Color
        public let cornerRadius: CGFloat
        public let fillAvailableSpace: Bool
        
        public init(
            font: Font? = nil,
            textColor: Color? = nil,
            backgroundColor: Color? = nil,
            borderWidth: CGFloat? = nil,
            borderColor: Color? = nil,
            cornerRadius: CGFloat? = nil,
            fillAvailableSpace: Bool = false
        ) {
            self.font = font ?? .knock2.weight(.medium)
            self.textColor = textColor ?? .white
            self.backgroundColor = backgroundColor ?? .clear
            self.borderWidth = borderWidth ?? 1
            self.borderColor = borderColor ?? KnockColor.Gray.gray6
            self.cornerRadius = cornerRadius ?? 4
            self.fillAvailableSpace = fillAvailableSpace
        }
    }
}

#Preview {
    HStack {
        Knock.ActionButton(title: "Primary", config: Knock.ActionButton.Style.primary.defaultConfig) {}
        Knock.ActionButton(title: "Secondary", config: Knock.ActionButton.Style.secondary.defaultConfig) {}
        Knock.ActionButton(title: "Tertiary", config: Knock.ActionButton.Style.tertiary.defaultConfig) {}
    }
}
