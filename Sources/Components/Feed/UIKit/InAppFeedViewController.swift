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
    public var viewModel = Knock.InAppFeedViewModel()
    public var theme: Knock.InAppFeedTheme = .init()
    
    public init(viewModel: Knock.InAppFeedViewModel = Knock.InAppFeedViewModel(), theme: Knock.InAppFeedTheme) {
        super.init(nibName: nil, bundle: nil)

        self.viewModel = viewModel
        self.theme = theme
    }
    
    required public init?(coder: NSCoder) {
        self.viewModel = Knock.InAppFeedViewModel() // Default value for viewModel
        self.theme = Knock.InAppFeedTheme() // Default value for theme
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
