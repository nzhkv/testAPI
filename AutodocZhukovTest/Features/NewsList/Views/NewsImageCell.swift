//
//  NewsImageCell.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class NewsImageCell: UICollectionViewCell {
    static let reuseIdentifier = "NewsImageCell"

    private let imageView = UIImageView()
    private let imageShimmer = ImageShimmerPlaceholderView()
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let readBadge = NewsReadBadgeView()
    private var imageTask: Task<Void, Never>?
    private var imageLoader: (any ImageLoaderProtocol)?
    private var currentItem: NewsItem?
    private var loadedImageURL: URL?
    private var didLoadRemoteImage = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        imageLoader = nil
        currentItem = nil
        loadedImageURL = nil
        didLoadRemoteImage = false
        showImagePlaceholder(animated: true)
        titleLabel.text = nil
        categoryLabel.text = nil
        readBadge.setVisible(false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if !didLoadRemoteImage, currentItem?.titleImageURL != nil, canonicalTargetWidth > 0 {
            loadImageIfNeeded()
        }
    }

    func configure(with item: NewsItem, imageLoader: any ImageLoaderProtocol, isRead: Bool, forceImageReload: Bool = false) {
        let isSameItem = currentItem?.id == item.id

        self.imageLoader = imageLoader
        currentItem = item
        titleLabel.text = item.title
        categoryLabel.text = item.category
        readBadge.setVisible(isRead)

        if !isSameItem || forceImageReload {
            imageTask?.cancel()
            imageTask = nil
            loadedImageURL = nil
            didLoadRemoteImage = false
            showImagePlaceholder(animated: !isSameItem)
        }

        loadImageIfNeeded()
    }

    private func loadImageIfNeeded() {
        guard
            imageTask == nil,
            let item = currentItem,
            let imageLoader,
            let imageURL = item.titleImageURL,
            canonicalTargetWidth > 0
        else {
            return
        }

        if loadedImageURL == imageURL, didLoadRemoteImage {
            return
        }

        loadedImageURL = imageURL
        showImagePlaceholder(animated: true)

        let targetWidth = canonicalTargetWidth
        let scale = min(window?.screen.scale ?? UIScreen.main.scale, 2)

        imageTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            if let cachedImage = await imageLoader.cachedImage(for: imageURL) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.applyLoadedImage(cachedImage, for: imageURL)
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
                    self.applyLoadedImage(image, for: imageURL)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if !self.didLoadRemoteImage {
                        self.showImagePlaceholder(animated: false)
                    }
                    self.imageTask = nil
                }
            }
        }
    }

    @MainActor
    private func applyLoadedImage(_ image: UIImage, for url: URL) {
        guard currentItem?.titleImageURL == url else {
            imageTask = nil
            return
        }

        imageView.image = image
        loadedImageURL = url
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

    private var canonicalTargetWidth: CGFloat {
        guard let collectionView = superview as? UICollectionView,
              collectionView.bounds.width > 0 else {
            return 0
        }

        return NewsListLayoutMetrics.canonicalImageTargetWidth(
            containerWidth: collectionView.bounds.width
        )
    }

    private func setupView() {
        NewsCellStyle.applyCardStyle(to: contentView)
        NewsCellStyle.applyImageStyle(to: imageView)
        NewsCellStyle.applyTitleStyle(to: titleLabel, numberOfLines: 3)
        NewsCellStyle.applyCategoryStyle(to: categoryLabel)

        let textStack = NewsCellStyle.makeTextStack(
            categoryLabel: categoryLabel,
            titleLabel: titleLabel
        )

        readBadge.translatesAutoresizingMaskIntoConstraints = false
        imageShimmer.translatesAutoresizingMaskIntoConstraints = false

        [imageView, imageShimmer, textStack, readBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let insets = NewsCellStyle.imageCellInsets
        let aspectRatio = imageView.heightAnchor.constraint(
            equalTo: imageView.widthAnchor,
            multiplier: NewsCellStyle.imageAspectRatio
        )
        aspectRatio.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            aspectRatio,

            imageShimmer.topAnchor.constraint(equalTo: imageView.topAnchor),
            imageShimmer.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            imageShimmer.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            imageShimmer.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            textStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: NewsCellStyle.imageTextSpacing),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.leading),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.trailing),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -insets.bottom),

            readBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            readBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        ])

        showImagePlaceholder(animated: false)
    }
}
