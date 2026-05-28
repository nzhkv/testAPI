//
//  SplashViewController.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class SplashViewController: UIViewController {
    private static let splashPreheatBatchSize = 6

    private let viewModel: NewsListViewModel
    private let imageLoader: any ImageLoaderProtocol
    private let readStatusManager: NewsReadStatusManager
    private weak var navigationDelegate: SplashNavigationDelegate?
    private let titleLabel = UILabel()
    private var loadingTask: Task<Void, Never>?

    init(
        viewModel: NewsListViewModel,
        imageLoader: any ImageLoaderProtocol,
        readStatusManager: NewsReadStatusManager,
        navigationDelegate: SplashNavigationDelegate
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.readStatusManager = readStatusManager
        self.navigationDelegate = navigationDelegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadFirstPage()
    }

    deinit {
        loadingTask?.cancel()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "Autodoc News"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func loadFirstPage() {
        loadingTask = Task { [weak self] in
            guard let self else { return }

            async let readStatusLoad: Void = readStatusManager.loadIfNeeded()
            async let cacheLoaded: Bool = viewModel.loadCachedNews()
            async let minimumDelay: Void = Task.sleep(for: minimumDisplayDuration)

            let hadCache = await cacheLoaded
            _ = await readStatusLoad

            if !hadCache {
                _ = await viewModel.refreshNews()
            }

            _ = try? await minimumDelay

            if hadCache {
                await viewModel.checkConnectivityAfterCacheDisplay()
            }

            await preheatVisibleImages()

            guard !Task.isCancelled else { return }

            navigationDelegate?.splashDidFinish(viewModel: viewModel)
        }
    }

    private func preheatVisibleImages() async {
        let items = viewModel.items
        guard !items.isEmpty else { return }

        await ImagePreheater.preheat(
            items: items,
            imageLoader: imageLoader,
            targetWidth: layoutImageTargetWidth,
            scale: layoutScale,
            batchSize: Self.splashPreheatBatchSize,
            priority: .display
        )
    }

    private var minimumDisplayDuration: Duration {
        .milliseconds(400)
    }

    private var layoutContainerWidth: CGFloat {
        if view.bounds.width > 0 {
            return view.bounds.width
        }

        if let windowWidth = view.window?.bounds.width, windowWidth > 0 {
            return windowWidth
        }

        return UIScreen.main.bounds.width
    }

    private var layoutImageTargetWidth: CGFloat {
        NewsListLayoutMetrics.canonicalImageTargetWidth(containerWidth: layoutContainerWidth)
    }

    private var layoutScale: CGFloat {
        min(view.window?.screen.scale ?? UIScreen.main.scale, 2)
    }
}
