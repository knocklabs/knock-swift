//
//  HtmlView.swift
//
//
//  Created by Matt Gardner on 4/16/24.
//

import Foundation
import SwiftUI
import UIKit

struct HtmlView: UIViewRepresentable {
    let html: String
    
    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<Self>) {
        DispatchQueue.main.async {
            let data = Data(self.html.utf8)
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                // For text visualisation only, no editing.
                uiView.isEditable = false
                uiView.backgroundColor = .clear
                
                // Make UITextView flex to available width, but require height to fit its content.
                // Also disable scrolling so the UITextView will set its `intrinsicContentSize` to match its text content.
                uiView.isScrollEnabled = false
                uiView.setContentHuggingPriority(.defaultLow, for: .vertical)
                uiView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                uiView.setContentCompressionResistancePriority(.required, for: .vertical)
                uiView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                uiView.attributedText = attributedString
            }
        }
    }
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UITextView {
        let label = UITextView()
        return label
    }
}
