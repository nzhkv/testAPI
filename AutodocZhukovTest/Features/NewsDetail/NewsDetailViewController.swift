//
//  NewsDetailViewController.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class NewsDetailViewController: UIViewController {
    private let item: NewsItem
    private let imageLoader: any ImageLoaderProtocol
    private let readStatusManager: NewsReadStatusManager

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let imageView = UIImageView()
    private let imageShimmer = ImageShimmerPlaceholderView()
    private let categoryLabel = UILabel()
    private let dateLabel = UILabel()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private var imageTask: Task<Void, Never>?
    private var didLoadRemoteImage = false
    private var hasMarkedAsRead = false

    init(
        item: NewsItem,
        imageLoader: any ImageLoaderProtocol,
        readStatusManager: NewsReadStatusManager
    ) {
        self.item = item
        self.imageLoader = imageLoader
        self.readStatusManager = readStatusManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        applyContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        markAsReadIfNeeded()
        loadImageIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        loadImageIfNeeded()
    }

    private func markAsReadIfNeeded() {
        guard !hasMarkedAsRead else { return }
        hasMarkedAsRead = true
        readStatusManager.markAsRead(item.id)
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
        title = item.category.isEmpty ? "Новость" : item.category

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NewsCellStyle.applyImageStyle(to: imageView)
        imageView.isHidden = item.titleImageURL == nil

        imageShimmer.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(imageShimmer)
        NSLayoutConstraint.activate([
            imageShimmer.topAnchor.constraint(equalTo: imageView.topAnchor),
            imageShimmer.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            imageShimmer.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            imageShimmer.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])

        if item.titleImageURL != nil {
            showImagePlaceholder(animated: true)
        }

        NewsCellStyle.applyCategoryStyle(to: categoryLabel)
        dateLabel.font = .preferredFont(forTextStyle: .subheadline)
        dateLabel.textColor = .secondaryLabel
        dateLabel.numberOfLines = 1
        dateLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.textColor = .label
        descriptionLabel.numberOfLines = 0
        descriptionLabel.adjustsFontForContentSizeCategory = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(imageView)
        contentStack.addArrangedSubview(categoryLabel)
        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(descriptionLabel)

        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: NewsCellStyle.imageAspectRatio)
        ])
    }

    private func applyContent() {
        categoryLabel.text = item.category
        categoryLabel.isHidden = item.category.isEmpty

        if let publishedDate = item.publishedDate {
            dateLabel.text = NewsDateFormatting.listFormatted(publishedDate)
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }

        titleLabel.text = item.title
        descriptionLabel.text = item.description
        descriptionLabel.isHidden = item.description.isEmpty
    }

    private func loadImageIfNeeded() {
        guard
            !didLoadRemoteImage,
            imageTask == nil,
            item.titleImageURL != nil,
            imageTargetWidth > 0
        else {
            return
        }

        guard let imageURL = item.titleImageURL else { return }

        let targetWidth = imageTargetWidth
        let scale = min(view.window?.screen.scale ?? UIScreen.main.scale, 2)
        showImagePlaceholder(animated: true)

        imageTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            if let cachedImage = await imageLoader.cachedImage(for: imageURL) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.applyLoadedImage(cachedImage)
                }
                return
            }

            do {
                let image = try await imageLoader.image(
                    for: imageURL,
                    targetWidth: targetWidth,
                    scale: scale,
                    priority: .display
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.applyLoadedImage(image)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.showImagePlaceholder(animated: false)
                    self.imageTask = nil
                }
            }
        }
    }

    @MainActor
    private func applyLoadedImage(_ image: UIImage) {
        imageView.image = image
        didLoadRemoteImage = true
        hideImagePlaceholder()
        imageTask = nil
    }

    private func showImagePlaceholder(animated: Bool) {
        imageView.image = nil
        imageShimmer.isHidden = false
        if animated {
            imageShimmer.startAnimating()
        } else {
            imageShimmer.stopAnimating()
        }
    }

    private func hideImagePlaceholder() {
        imageShimmer.stopAnimating()
        imageShimmer.isHidden = true
    }

    private var imageTargetWidth: CGFloat {
        let containerWidth: CGFloat
        if view.bounds.width > 0 {
            containerWidth = view.bounds.width
        } else {
            containerWidth = view.window?.bounds.width ?? UIScreen.main.bounds.width
        }

        return NewsListLayoutMetrics.canonicalImageTargetWidth(containerWidth: containerWidth)
    }
}
