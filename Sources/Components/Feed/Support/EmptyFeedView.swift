//
//  EmptyFeedView.swift
//
//
//  Created by Matt Gardner on 4/23/24.
//

import SwiftUI

extension Knock {
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
}

#Preview {
    let filter = Knock.InAppFeedFilter(scope: .archived)
    return Knock.EmptyFeedView(config: filter.emptyViewConfig) {}
}
