//
//  NewsListViewController.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Combine
import UIKit

final class NewsListViewController: UIViewController {
    private let mainSection = "main"
    private let viewModel: NewsListViewModel
    private let imageLoader: any ImageLoaderProtocol
    private let readStatusManager: NewsReadStatusManager
    private weak var navigationDelegate: NewsListNavigationDelegate?
    private let imagePreheatCoordinator: NewsListImagePreheatCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<String, NewsItem>!

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeLayout()
    )

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private lazy var errorStack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
    private let offlineBannerLabel = UILabel()
    private lazy var offlineBanner = makeOfflineBanner()
    private var offlineBannerHeightConstraint: NSLayoutConstraint?
    private var didRequestConnectivityCheck = false
    private var shouldForceImageReload = false
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
        return control
    }()
    private var latestPrefetchedItems: [NewsItem] = []
    private var prefetchedPageImagePreheatTask: Task<Void, Never>?
    private var isCompletionFooterVisible = false
    private var lastPreheatContainerWidth: CGFloat = 0

    init(
        viewModel: NewsListViewModel,
        imageLoader: any ImageLoaderProtocol,
        readStatusManager: NewsReadStatusManager,
        navigationDelegate: NewsListNavigationDelegate
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.readStatusManager = readStatusManager
        self.navigationDelegate = navigationDelegate
        self.imagePreheatCoordinator = NewsListImagePreheatCoordinator(imageLoader: imageLoader)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupDataSource()
        bindViewModel()
        syncPresentationState()
        registerForTraitChanges(
            [UITraitVerticalSizeClass.self, UITraitUserInterfaceIdiom.self]
        ) { (self: Self, previousTraitCollection: UITraitCollection) in
            guard Self.columnsLayoutDidChange(from: previousTraitCollection, to: self.traitCollection) else {
                return
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            self.reconfigureVisibleItems()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didRequestConnectivityCheck, !viewModel.items.isEmpty else { return }
        didRequestConnectivityCheck = true

        Task {
            await viewModel.checkConnectivityAfterCacheDisplay()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = collectionView.bounds.width
        guard width > 0, width != lastPreheatContainerWidth else { return }

        lastPreheatContainerWidth = width
        enqueueImagePreheat(for: viewModel.items)
        preheatPrefetchedPageIfNeeded(latestPrefetchedItems)
    }

    private func setupView() {
        title = "Новости"
        view.backgroundColor = .systemBackground

        collectionView.backgroundColor = .systemBackground
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.refreshControl = refreshControl
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.register(NewsImageCell.self, forCellWithReuseIdentifier: NewsImageCell.reuseIdentifier)
        collectionView.register(NewsTextCell.self, forCellWithReuseIdentifier: NewsTextCell.reuseIdentifier)
        collectionView.register(
            NewsCompletionFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: NewsCompletionFooterView.reuseIdentifier
        )

        errorLabel.text = "Проверьте сетевое соединение"
        errorLabel.font = .preferredFont(forTextStyle: .headline)
        errorLabel.textAlignment = .center
        errorLabel.textColor = .label
        errorLabel.numberOfLines = 0

        retryButton.setTitle("Повторить", for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

        errorStack.axis = .vertical
        errorStack.alignment = .center
        errorStack.spacing = 12
        errorStack.isHidden = true

        offlineBanner.translatesAutoresizingMaskIntoConstraints = false
        offlineBanner.isHidden = true

        [collectionView, loadingIndicator, errorStack, offlineBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let offlineBannerHeight = offlineBanner.heightAnchor.constraint(equalToConstant: 0)
        offlineBannerHeightConstraint = offlineBannerHeight

        NSLayoutConstraint.activate([
            offlineBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            offlineBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineBannerHeight,

            collectionView.topAnchor.constraint(equalTo: offlineBanner.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<String, NewsItem>(
            collectionView: collectionView
        ) { [imageLoader, readStatusManager] collectionView, indexPath, item in
            let isRead = readStatusManager.isRead(item.id)
            let centersTextVertically = NewsListLayoutMetrics.columns(for: collectionView.traitCollection) > 1

            if item.titleImageURL == nil {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: NewsTextCell.reuseIdentifier,
                    for: indexPath
                ) as? NewsTextCell
                cell?.configure(with: item, isRead: isRead, centersTextVertically: centersTextVertically)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: NewsImageCell.reuseIdentifier,
                    for: indexPath
                ) as? NewsImageCell
                cell?.configure(
                    with: item,
                    imageLoader: imageLoader,
                    isRead: isRead,
                    forceImageReload: self.shouldForceImageReload
                )
                return cell
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionFooter else {
                return nil
            }

            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: NewsCompletionFooterView.reuseIdentifier,
                for: indexPath
            ) as? NewsCompletionFooterView
            footer?.configure(isVisible: self?.viewModel.didLoadAllNews == true)
            return footer
        }

        applySnapshot(items: viewModel.items, animatingDifferences: false)
    }

    private func bindViewModel() {
        viewModel.$items
            .sink { [weak self] items in
                self?.applySnapshot(items: items)
                self?.updateEmptyState()
                self?.updateOfflineBanner()
                self?.updateCompletionFooterIfNeeded()
                self?.enqueueImagePreheat(for: items)
            }
            .store(in: &cancellables)

        viewModel.$prefetchedItems
            .sink { [weak self] items in
                self?.latestPrefetchedItems = items
                self?.preheatPrefetchedPageIfNeeded(items)
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .sink { [weak self] isLoading in
                self?.updateLoadingPresentation(isLoading: isLoading)
                self?.syncPresentationState()

                if !isLoading {
                    self?.loadNextPageIfNearBottom()
                }
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .sink { [weak self] _ in
                self?.syncPresentationState()
            }
            .store(in: &cancellables)

        viewModel.$isNetworkUnavailable
            .sink { [weak self] _ in
                self?.syncPresentationState()
            }
            .store(in: &cancellables)

        viewModel.$imageReloadNonce
            .dropFirst()
            .sink { [weak self] _ in
                self?.reloadVisibleImages()
            }
            .store(in: &cancellables)

        readStatusManager.$readIDs
            .sink { [weak self] readIDs in
                self?.reloadReadState(for: readIDs)
            }
            .store(in: &cancellables)
    }

    private func applySnapshot(items: [NewsItem], animatingDifferences: Bool = true) {
        let currentItems = dataSource.snapshot().itemIdentifiers

        guard currentItems != items else { return }

        var snapshot = NSDiffableDataSourceSnapshot<String, NewsItem>()
        snapshot.appendSections([mainSection])
        snapshot.appendItems(items, toSection: mainSection)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func syncPresentationState() {
        updateEmptyState()
        updateOfflineBanner()
        updateLoadingPresentation(isLoading: viewModel.isLoading)
    }

    private func updateEmptyState() {
        let hasNetworkError = viewModel.isNetworkUnavailable
        let hasOtherError = viewModel.errorMessage != nil
        let shouldShowError = viewModel.items.isEmpty
            && (hasNetworkError || hasOtherError)
            && !viewModel.isLoading

        if hasNetworkError {
            errorLabel.text = "Проверьте сетевое соединение"
        } else {
            errorLabel.text = viewModel.errorMessage ?? "Что-то пошло не так"
        }

        retryButton.isHidden = !hasNetworkError
        errorStack.isHidden = !shouldShowError
        collectionView.isHidden = shouldShowError
    }

    private func updateOfflineBanner() {
        let shouldShowFullScreenError = viewModel.items.isEmpty
            && viewModel.isNetworkUnavailable
            && !viewModel.isLoading

        let shouldShow = viewModel.isNetworkUnavailable
            && !viewModel.items.isEmpty
            && !shouldShowFullScreenError

        offlineBannerLabel.text = "Проверьте сетевое соединение"
        offlineBanner.isHidden = !shouldShow
        offlineBannerHeightConstraint?.constant = shouldShow ? 44 : 0
    }

    private func makeOfflineBanner() -> UIView {
        offlineBannerLabel.font = .preferredFont(forTextStyle: .subheadline)
        offlineBannerLabel.textColor = .label
        offlineBannerLabel.textAlignment = .center
        offlineBannerLabel.numberOfLines = 2

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        offlineBannerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(offlineBannerLabel)

        NSLayoutConstraint.activate([
            offlineBannerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            offlineBannerLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            offlineBannerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            offlineBannerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }

    private func reloadVisibleImages() {
        var snapshot = dataSource.snapshot()
        let imageItems = snapshot.itemIdentifiers.filter { $0.titleImageURL != nil }
        guard !imageItems.isEmpty else { return }

        shouldForceImageReload = true
        snapshot.reconfigureItems(imageItems)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.shouldForceImageReload = false
        }
    }

    private func updateCompletionFooterIfNeeded() {
        guard isCompletionFooterVisible != viewModel.didLoadAllNews else { return }

        isCompletionFooterVisible = viewModel.didLoadAllNews
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func makeLayout() -> UICollectionViewLayout {
        NewsListCollectionLayoutBuilder.makeLayout(
            columnsProvider: NewsListLayoutMetrics.columns,
            showsCompletionFooter: { [weak self] in
                self?.viewModel.didLoadAllNews == true
            }
        )
    }

    @objc private func retryButtonTapped() {
        Task {
            await viewModel.refreshNews()
        }
    }

    @objc private func refreshControlTriggered() {
        guard isCollectionViewAtTop else {
            refreshControl.endRefreshing()
            return
        }

        Task {
            await viewModel.refreshNews()
            refreshControl.endRefreshing()
        }
    }

    private var isCollectionViewAtTop: Bool {
        collectionView.contentOffset.y + collectionView.adjustedContentInset.top <= 0
    }

    private func updateLoadingPresentation(isLoading: Bool) {
        if isLoading, viewModel.items.isEmpty {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }

        if !isLoading {
            refreshControl.endRefreshing()
        }
    }

    private func reloadReadState(for readIDs: Set<Int>) {
        var snapshot = dataSource.snapshot()
        let itemsToReload = snapshot.itemIdentifiers.filter { readIDs.contains($0.id) }

        guard !itemsToReload.isEmpty else { return }

        snapshot.reconfigureItems(itemsToReload)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func loadNextPageIfNearBottom() {
        guard isNearBottomOfContent else { return }

        let visibleItems = collectionView.indexPathsForVisibleItems
            .sorted()
            .compactMap { dataSource.itemIdentifier(for: $0) }

        let triggerItem = visibleItems.last ?? viewModel.items.last
        viewModel.loadNextPageIfNeeded(currentItem: triggerItem)
    }

    private var isNearBottomOfContent: Bool {
        let visibleHeight = collectionView.bounds.height
            - collectionView.adjustedContentInset.top
            - collectionView.adjustedContentInset.bottom
        guard visibleHeight > 0 else { return false }

        let distanceToBottom = collectionView.contentSize.height
            - collectionView.contentOffset.y
            - collectionView.adjustedContentInset.top
            - visibleHeight

        return distanceToBottom < visibleHeight
    }

    private func preheatPrefetchedPageIfNeeded(_ items: [NewsItem]) {
        guard !items.isEmpty, prefetchedPageImagePreheatTask == nil else { return }

        let containerWidth = collectionView.bounds.width
        guard containerWidth > 0 else { return }

        let scale = min(collectionView.window?.screen.scale ?? UIScreen.main.scale, 2)
        let targetWidth = NewsListLayoutMetrics.canonicalImageTargetWidth(containerWidth: containerWidth)
        let imageLoader = imageLoader
        let coordinator = imagePreheatCoordinator
        let itemIDs = items.map(\.id)

        prefetchedPageImagePreheatTask = Task {
            await ImagePreheater.preheat(
                items: items,
                imageLoader: imageLoader,
                targetWidth: targetWidth,
                scale: scale,
                batchSize: 6,
                priority: .display
            )
            await MainActor.run {
                coordinator.markPrefetched(itemIDs: itemIDs)
                prefetchedPageImagePreheatTask = nil
            }
        }
    }

    private func enqueueImagePreheat(for items: [NewsItem]) {
        guard !items.isEmpty else { return }

        let scale = min(collectionView.window?.screen.scale ?? UIScreen.main.scale, 2)
        imagePreheatCoordinator.enqueue(
            items: items,
            containerWidth: collectionView.bounds.width,
            scale: scale
        )
    }

    private func reconfigureVisibleItems() {
        var snapshot = dataSource.snapshot()
        let textOnlyItems = collectionView.indexPathsForVisibleItems
            .compactMap { dataSource.itemIdentifier(for: $0) }
            .filter { $0.titleImageURL == nil }

        guard !textOnlyItems.isEmpty else { return }

        snapshot.reconfigureItems(textOnlyItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private static func columnsLayoutDidChange(from previous: UITraitCollection, to current: UITraitCollection) -> Bool {
        NewsListLayoutMetrics.columns(for: previous) != NewsListLayoutMetrics.columns(for: current)
    }
}

extension NewsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        navigationDelegate?.newsList(self, didSelect: item)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        loadNextPageIfNearBottom()
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let item = dataSource.itemIdentifier(for: indexPath)
        viewModel.loadNextPageIfNeeded(currentItem: item)
    }
}
