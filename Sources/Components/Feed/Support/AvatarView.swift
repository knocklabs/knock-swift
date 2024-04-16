//
//  AvatarView.swift
//
//
//  Created by Matt Gardner on 4/15/24.
//

import SwiftUI

struct AvatarView: View {
    let imageURLString: String?
    let name: String?
    var size: CGFloat? = nil
    
    private var _size: CGFloat {
        return size ?? 50
    }
    
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
        .frame(width: _size, height: _size)
        .background(Color.gray.opacity(0.1))
        .foregroundColor(.primary)
        .font(.headline)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
    }
    
    @ViewBuilder
    private func initialsView() -> some View {
        if let initials = generateInitials() {
            Text(initials)
                .fontWeight(.bold)
        } else {
            Image(systemName: "person")
                .resizable()
                .padding()
        }
    }
    
    func generateInitials() -> String? {
        guard let name = name else { return nil }
        let nameComponents = name.split(separator: " ")
        let initials = nameComponents.compactMap { $0.first?.uppercased() }
        return initials.joined()
    }
}

#Preview {
    HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 24) {
        AvatarView(imageURLString: nil, name: "Dennis Nedry")
        AvatarView(imageURLString: nil, name: "Dennis")
        AvatarView(imageURLString: "https://xsgames.co/randomusers/assets/avatars/male/2.jpg", name: "Dennis Nedry")
        AvatarView(imageURLString: nil, name: nil)
    }
}
