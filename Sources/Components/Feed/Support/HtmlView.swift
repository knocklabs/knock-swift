//
//  HtmlView.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI
import UIKit
import WebKit

extension Knock {
    struct HtmlView: UIViewRepresentable {
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
        
        func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<Self>) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            let htmlStart = """
                <head>
                    <style>
                        \(_css)
                    </style>
                </head>
            """
            
            let full = "\(htmlStart)\(html)"
            
            DispatchQueue.main.async {
                if let data = full.data(using: .utf8),
                   let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                    uiView.attributedText = attributedString
                }
            }
        }
        
        func makeUIView(context: UIViewRepresentableContext<Self>) -> UITextView {
            let textView = UITextView()
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            
            textView.isEditable = false
            textView.backgroundColor = .clear
            textView.isScrollEnabled = false
            textView.setContentHuggingPriority(.defaultLow, for: .vertical)
            textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            textView.setContentCompressionResistancePriority(.required, for: .vertical)
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            return textView
        }
    }
}
