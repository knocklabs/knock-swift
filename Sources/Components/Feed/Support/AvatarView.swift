//
//  AvatarView.swift
//
//
//  Created by Matt Gardner on 4/15/24.
//

import SwiftUI

extension Knock {
    struct AvatarView: View {
        let imageURLString: String?
        let name: String?
        var backgroundColor: Color = KnockColor.Gray.gray5
        var font: Font = .knock1.weight(.medium)
        var textColor: Color = KnockColor.Gray.gray11
        var size: CGFloat = 32
        
        var body: some View {
            Group {
                if let imageString = imageURLString, let url = URL(string: imageString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            initialsView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            initialsView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    initialsView()
                }
            }
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(Circle())
        }
        
        @ViewBuilder
        private func initialsView() -> some View {
            if let initials = generateInitials() {
                Text(initials)
                    .font(font)
                    .foregroundColor(textColor)
            } else {
                EmptyView()
            }
        }
        
        func generateInitials() -> String? {
            guard let name = name else { return nil }
            let nameComponents = name.split(separator: " ")
            let initials = nameComponents.compactMap { $0.first?.uppercased() }
            return initials.joined()
        }
    }

}

#Preview {
    HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 24) {
        Knock.AvatarView(imageURLString: nil, name: "Dennis Nedry")
        Knock.AvatarView(imageURLString: nil, name: "Dennis")
        Knock.AvatarView(imageURLString: "https://xsgames.co/randomusers/assets/avatars/male/2.jpg", name: "Dennis Nedry")
        Knock.AvatarView(imageURLString: nil, name: nil)
    }
}
