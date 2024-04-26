//
//  KnockFonts.swift
//
//
//  Created by Matt Gardner on 4/25/24.
//

import Foundation
import SwiftUI
import UIKit

extension Font {
    static func customBody(size: CGFloat) -> Font {
        return Font.system(size: size)
    }
    static let knock0 = Font.customBody(size: 11)
    static let knock1 = Font.customBody(size: 12)
    static let knock2 = Font.customBody(size: 14)
    static let knock3 = Font.customBody(size: 16)
    static let knock4 = Font.customBody(size: 18)
    static let knock5 = Font.customBody(size: 20)
    static let knock6 = Font.customBody(size: 24)
    static let knock7 = Font.customBody(size: 30)
    static let knock8 = Font.customBody(size: 36)
    static let knock9 = Font.customBody(size: 48)
}

extension UIFont {
    static let knock0 = UIFont.systemFont(ofSize: 11)
    static let knock1 = UIFont.systemFont(ofSize: 12)
    static let knock2 = UIFont.systemFont(ofSize: 14)
    static let knock3 = UIFont.systemFont(ofSize: 16)
    static let knock4 = UIFont.systemFont(ofSize: 18)
    static let knock5 = UIFont.systemFont(ofSize: 20)
    static let knock6 = UIFont.systemFont(ofSize: 24)
    static let knock7 = UIFont.systemFont(ofSize: 30)
    static let knock8 = UIFont.systemFont(ofSize: 36)
    static let knock9 = UIFont.systemFont(ofSize: 48)
}
