//
//  NewsListViewModel.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Combine
import Foundation

@MainActor
final class NewsListViewModel {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var prefetchedItems: [NewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isNetworkUnavailable = false
    @Published private(set) var imageReloadNonce = 0

    private let apiClient: NewsAPIClientProtocol
    private let cacheStore: NewsCacheStoreProtocol
    private let networkMonitor: NetworkStatusMonitoring
    private let pageSize: Int
    private var currentPage = 1
    private var totalCount = 0
    private var prefetchedPage: NewsPage?
    private var prefetchedPageNumber: Int?
    private var prefetchTask: Task<Void, Never>?
    private var loadNextPageTask: Task<Void, Never>?

    private var canLoadMore: Bool {
        !isLoading && (totalCount == 0 || items.count < totalCount)
    }

    deinit {
        prefetchTask?.cancel()
        loadNextPageTask?.cancel()
    }

    var didLoadAllNews: Bool {
        totalCount > 0 && !items.isEmpty && items.count >= totalCount
    }

    init(
        apiClient: NewsAPIClientProtocol? = nil,
        cacheStore: NewsCacheStoreProtocol? = nil,
        networkMonitor: NetworkStatusMonitoring? = nil,
        pageSize: Int = 15
    ) {
        self.apiClient = apiClient ?? NewsAPIClient()
        self.cacheStore = cacheStore ?? NewsCacheStore()
        self.networkMonitor = networkMonitor ?? NetworkPathMonitor.shared
        self.pageSize = pageSize

        self.networkMonitor.start()
        self.networkMonitor.setStatusHandler { [weak self] isConnected in
            self?.handleNetworkStatusChange(isConnected: isConnected)
        }
    }

    @discardableResult
    func loadCachedNews() async -> Bool {
        guard let cachedPage = await cacheStore.loadFirstPage() else {
            return false
        }

        guard items.isEmpty else {
            return true
        }

        errorMessage = nil
        apply(pageNumber: 1, page: cachedPage, reset: true)
        updateNetworkUnavailableFromPath()
        return true
    }

    func checkConnectivityAfterCacheDisplay() async {
        guard !items.isEmpty else { return }

        updateNetworkUnavailableFromPath()
        guard networkMonitor.isConnected else { return }

        await refreshNewsSilentlyKeepingCache()
    }

    private func handleNetworkStatusChange(isConnected: Bool) {
        if isConnected {
            isNetworkUnavailable = false
        } else {
            updateNetworkUnavailableFromPath()
        }
    }

    private func updateNetworkUnavailableFromPath() {
        guard !networkMonitor.isConnected else {
            return
        }

        isNetworkUnavailable = true
        if !items.isEmpty {
            errorMessage = nil
        }
    }

    @discardableResult
    func refreshNews() async -> Bool {
        await loadPage(1, reset: true)
    }

    @discardableResult
    func refreshNewsSilentlyKeepingCache() async -> Bool {
        await loadPage(1, reset: true)
    }

    func loadNextPageIfNeeded(currentItem: NewsItem?) {
        guard canLoadMore else { return }

        guard let currentItem else {
            scheduleLoadNextPage()
            return
        }

        guard let currentIndex = items.firstIndex(where: { $0.id == currentItem.id }) else { return }

        let thresholdIndex = items.index(items.endIndex, offsetBy: -5, limitedBy: items.startIndex) ?? items.startIndex
        guard currentIndex >= thresholdIndex else { return }

        scheduleLoadNextPage()
    }

    private func scheduleLoadNextPage() {
        guard loadNextPageTask == nil else { return }

        loadNextPageTask = Task { [weak self] in
            guard let self else { return }
            await loadNextPage()
            loadNextPageTask = nil
        }
    }

    private func loadNextPage() async {
        guard canLoadMore else { return }

        if applyPrefetchedPageIfPossible() {
            prefetchNextPageIfNeeded()
            return
        }

        await loadPage(currentPage + 1, reset: false)
    }

    @discardableResult
    private func loadPage(_ page: Int, reset: Bool) async -> Bool {
        guard !isLoading else { return false }

        if !reset, page > 1, items.count >= page * pageSize {
            prefetchNextPageIfNeeded()
            return true
        }

        isLoading = true
        errorMessage = nil

        let hadNetworkIssue = isNetworkUnavailable

        do {
            let loadedPage = try await apiClient.fetchNews(page: page, pageSize: pageSize)

            if networkMonitor.isConnected {
                isNetworkUnavailable = false
            }

            if shouldApply(page: loadedPage, pageNumber: page, reset: reset) {
                apply(pageNumber: page, page: loadedPage, reset: reset)
                prefetchNextPageIfNeeded()
            } else {
                prefetchNextPageIfNeeded()
                if reset, page == 1, hadNetworkIssue {
                    imageReloadNonce += 1
                }
            }

            if page == 1 {
                await cacheStore.saveFirstPage(loadedPage)
            }

            isLoading = false
            return true
        } catch {
            handleLoadFailure(error: error, page: page, reset: reset)
            isLoading = false
            return false
        }
    }

    private func handleLoadFailure(error: Error, page: Int, reset: Bool) {
        guard isNetworkError(error) else {
            if items.isEmpty {
                isNetworkUnavailable = false
                errorMessage = userMessage(for: error)
            }
            return
        }

        isNetworkUnavailable = true

        if items.isEmpty {
            errorMessage = nil
            return
        }

        guard reset, page == 1 else { return }

        errorMessage = nil
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isNetworkError(underlying)
        }

        return false
    }

    private func userMessage(for error: Error) -> String {
        if case NewsAPIError.decoding = error {
            return "Что-то пошло не так"
        }

        return "Что-то пошло не так"
    }

    private func shouldApply(page: NewsPage, pageNumber: Int, reset: Bool) -> Bool {
        guard reset, pageNumber == 1 else { return true }
        return !isSameFirstPage(page)
    }

    private func isSameFirstPage(_ page: NewsPage) -> Bool {
        NewsPage(items: items, totalCount: totalCount) == page
    }

    private func apply(pageNumber: Int, page: NewsPage, reset: Bool) {
        totalCount = page.totalCount

        if reset {
            currentPage = pageNumber
            items = page.items
            clearPrefetchedPage()
        } else {
            currentPage = pageNumber
            items += page.items
        }
    }

    private func applyPrefetchedPageIfPossible() -> Bool {
        let nextPageNumber = currentPage + 1

        guard
            prefetchedPageNumber == nextPageNumber,
            let prefetchedPage
        else {
            return false
        }

        clearPrefetchedPage()
        apply(pageNumber: nextPageNumber, page: prefetchedPage, reset: false)
        return true
    }

    private func prefetchNextPageIfNeeded() {
        guard
            !didLoadAllNews,
            prefetchTask == nil,
            prefetchedPage == nil
        else {
            return
        }

        let nextPageNumber = currentPage + 1

        if items.count >= nextPageNumber * pageSize {
            return
        }

        prefetchTask = Task { [weak self] in
            guard let self else { return }

            do {
                let page = try await apiClient.fetchNews(page: nextPageNumber, pageSize: pageSize)
                guard !Task.isCancelled else { return }

                prefetchedPage = page
                prefetchedPageNumber = nextPageNumber
                prefetchedItems = page.items
            } catch {}

            prefetchTask = nil
        }
    }

    private func clearPrefetchedPage() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchedPage = nil
        prefetchedPageNumber = nil
        prefetchedItems = []
    }
}
