//
//  KnockColors.swift
//
//
//  Created by Matt Gardner on 4/19/24.
//

import Foundation
import SwiftUI

public enum KnockColor {
    public enum Gray {
        public static let gray3 = Color("Gray3", bundle: Bundle.module)
        public static let gray4 = Color("Gray4", bundle: Bundle.module)
        public static let gray5 = Color("Gray5", bundle: Bundle.module)
        public static let gray6 = Color("Gray6", bundle: Bundle.module)
        public static let gray9 = Color("Gray9", bundle: Bundle.module)
        public static let gray11 = Color("Gray11", bundle: Bundle.module)
        public static let gray12 = Color("Gray12", bundle: Bundle.module)
    }
    
    public enum Accent {
        public static let accent3 = Color("Accent3", bundle: .module)
        public static let accent9 = Color("Accent9", bundle: .module)
        public static let accent11 = Color("Accent11", bundle: .module)
    }
    
    public enum Surface {
        public static let surface1 = Color("Surface1", bundle: .module)
    }
    
    public enum Blue {
        public static let blue9 = Color("Blue9", bundle: .module)
    }
    
    public enum Green {
        public static let green9 = Color("Green9", bundle: .module)
    }
}

//extension Bundle {
//    
//    internal static func current(for className: AnyClass) -> Bundle {
//        #if SWIFT_PACKAGE
//        return Bundle.module
//        #else
//        let bundle = Bundle(for: className)
//        return Bundle(url: bundle.url(forResource: "Colors", withExtension: "bundle")!)!
//        #endif
//    }
//}
