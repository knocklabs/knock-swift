//
//  HtmlView.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI
import UIKit

extension Knock {
    @available(iOS 15, *)
    struct HTMLTextView: View {
        @Environment(\.colorScheme) var colorScheme
        
        let html: String
        var css: String? = nil
        
        var _css: String {
            css ?? """
                * {
                    font-family: -apple-system, sans-serif;
                    font-size: 16px;
                    color: \(colorScheme == .dark ? "edeef0" : "1c2024");
                }
                p {
                    margin-top: 0px;
                    margin-bottom: 10px;
                }
                blockquote p {
                    color: \(colorScheme == .dark ? "b0b4ba" : "60646c");
                    margin-top: 0px;
                    margin-bottom: 10px;
                }
            """
        }
        
        var body: some View {
            let htmlStart = """
                <head>
                    <style>
                        \(_css)
                    </style>
                </head>
            """
            
            let full = "\(htmlStart)\(html)"
            
            if let nsAttributedString = try? NSAttributedString(data: Data(full.utf8), options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil),
               let attributedString = try? AttributedString(nsAttributedString, including: \.uiKit) {
                Text(attributedString)
            } else {
                Text(html)
            }
        }
    }
}
