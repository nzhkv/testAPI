//
//  AppDependencies.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

struct AppDependencies {
    let apiClient: NewsAPIClientProtocol
    let cacheStore: NewsCacheStoreProtocol
    let imageLoader: ImageLoaderProtocol
    let readStatusManager: NewsReadStatusManager
    let networkMonitor: NetworkStatusMonitoring

    @MainActor
    static let live: AppDependencies = {
        let networkMonitor = NetworkPathMonitor.shared
        networkMonitor.start()
        return AppDependencies(
            apiClient: NewsAPIClient(),
            cacheStore: NewsCacheStore(),
            imageLoader: ImageLoader.shared,
            readStatusManager: NewsReadStatusManager(store: NewsReadStore()),
            networkMonitor: networkMonitor
        )
    }()
}
