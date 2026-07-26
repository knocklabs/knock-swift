//
//  InAppFeedViewController.swift
//
//
//  Created by Matt Gardner on 4/26/24.
//

import Foundation
import UIKit
import SwiftUI

open class InAppFeedViewController: UIViewController {
    public var viewModel: Knock.InAppFeedViewModel
    public var theme: Knock.InAppFeedTheme

    // Note: `viewModel` has no default argument because `Knock.InAppFeedViewModel`
    // is `@MainActor`-isolated, and default-argument expressions are evaluated
    // in the caller's isolation context (not the init's). A `convenience init`
    // preserves the old "just pass a theme" call site without breaking isolation.
    public init(viewModel: Knock.InAppFeedViewModel, theme: Knock.InAppFeedTheme) {
        self.viewModel = viewModel
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    public convenience init(theme: Knock.InAppFeedTheme) {
        self.init(viewModel: Knock.InAppFeedViewModel(), theme: theme)
    }

    required public init?(coder: NSCoder) {
        self.viewModel = Knock.InAppFeedViewModel()
        self.theme = Knock.InAppFeedTheme()
        super.init(coder: coder)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the SwiftUI view, passing in the necessary environment objects
        let inAppView = Knock.InAppFeedView(theme: theme).environmentObject(viewModel)
        let hostingController = UIHostingController(rootView: inAppView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
