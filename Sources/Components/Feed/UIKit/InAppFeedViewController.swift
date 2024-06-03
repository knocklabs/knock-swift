//
//  InAppFeedViewController.swift
//
//
//  Created by Matt Gardner on 4/26/24.
//

import Foundation
import UIKit
import SwiftUI

class InAppFeedViewController: UIViewController {
    var viewModel = Knock.InAppFeedViewModel() // Regular property
    public var theme: Knock.InAppFeedTheme = .init()
    
    override func viewDidLoad() {
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
