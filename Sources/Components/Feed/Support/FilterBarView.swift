//
//  FilterBarView.swift
//
//
//  Created by Matt Gardner on 6/24/24.
//

import Foundation
import SwiftUI

extension Knock {
    struct FilterBarView: View {
        var filters: [InAppFeedFilter]
        @Binding var selectedFilter: InAppFeedFilter
        let theme: FilterBarTheme = FilterBarTheme()
        
        var body: some View {
            ZStack(alignment: .bottom) {
                Divider()
                    .frame(height: 1)
                    .background(KnockColor.Gray.gray4)

                HStack(spacing: .zero
                ) {
                    ForEach(filters, id: \.self) { option in
                        Text(option.title)
                            .font(theme.font)
                            .foregroundColor(option == selectedFilter ? theme.selectedColor : theme.unselectedColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(option == selectedFilter ? theme.selectedColor : .clear),
                                alignment: .bottom
                            )
                            .onTapGesture {
                                withAnimation {
                                    selectedFilter = option
                                }
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
    }
}
