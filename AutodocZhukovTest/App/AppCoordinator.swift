//
//  AppCoordinator.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

@MainActor
final class AppCoordinator {
    private let navigationController: UINavigationController
    private let dependencies: AppDependencies

    init(navigationController: UINavigationController, dependencies: AppDependencies) {
        self.navigationController = navigationController
        self.dependencies = dependencies
    }

    func start() {
        let viewModel = makeNewsListViewModel()
        let splashViewController = SplashViewController(
            viewModel: viewModel,
            imageLoader: dependencies.imageLoader,
            readStatusManager: dependencies.readStatusManager,
            navigationDelegate: self
        )
        navigationController.setViewControllers([splashViewController], animated: false)
    }

    private func makeNewsListViewModel() -> NewsListViewModel {
        NewsListViewModel(
            apiClient: dependencies.apiClient,
            cacheStore: dependencies.cacheStore,
            networkMonitor: dependencies.networkMonitor
        )
    }
}

extension AppCoordinator: SplashNavigationDelegate {
    func splashDidFinish(viewModel: NewsListViewModel) {
        navigationController.setNavigationBarHidden(false, animated: true)

        let newsListViewController = NewsListViewController(
            viewModel: viewModel,
            imageLoader: dependencies.imageLoader,
            readStatusManager: dependencies.readStatusManager,
            navigationDelegate: self
        )
        navigationController.setViewControllers([newsListViewController], animated: true)
    }
}

extension AppCoordinator: NewsListNavigationDelegate {
    func newsList(_ newsList: NewsListViewController, didSelect item: NewsItem) {
        let detailViewController = NewsDetailViewController(
            item: item,
            imageLoader: dependencies.imageLoader,
            readStatusManager: dependencies.readStatusManager
        )
        navigationController.pushViewController(detailViewController, animated: true)
    }
}
