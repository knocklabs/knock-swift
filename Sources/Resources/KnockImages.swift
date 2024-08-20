//
//  File.swift
//  
//
//  Created by Matt Gardner on 4/25/24.
//

import Foundation
import SwiftUI

class KnockImageBundleHelper {}

extension Bundle {
    internal static func currentImage(for className: AnyClass) -> Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let bundle = Bundle(for: className)
        guard let resourceBundleURL = bundle.url(forResource: "Media", withExtension: "bundle"),
              let resourceBundle = Bundle(url: resourceBundleURL) else {
            fatalError("Media.bundle not found!")
        }
        return resourceBundle
        #endif
    }
}

struct KnockImages {
    static let poweredByKnockIcon = Image("PoweredByKnockIcon", bundle: .currentImage(for: KnockImageBundleHelper.self))
}
