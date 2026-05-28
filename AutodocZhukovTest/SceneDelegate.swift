//
//  SceneDelegate.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = AppCoordinator(
            navigationController: navigationController,
            dependencies: .live
        )
        coordinator.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
        self.coordinator = coordinator
    }
}
