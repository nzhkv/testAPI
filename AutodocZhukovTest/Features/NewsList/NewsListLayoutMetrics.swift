//
//  NewsListLayoutMetrics.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

enum NewsListLayoutMetrics {
    nonisolated static let sectionInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)
    nonisolated static let interItemSpacing: CGFloat = 16
    nonisolated static let interGroupSpacing: CGFloat = 16
    nonisolated static let imageAspectRatio: CGFloat = 9.0 / 16.0
    private nonisolated static let imageTextSpacing: CGFloat = 12
    private nonisolated static let imageCellVerticalInsets: CGFloat = 24
    private nonisolated static let imageTextBlockEstimatedHeight: CGFloat = 72

    nonisolated static func columns(for traitCollection: UITraitCollection) -> Int {
        if traitCollection.userInterfaceIdiom == .pad {
            return 2
        }

        if traitCollection.verticalSizeClass == .compact {
            return 2
        }

        return 1
    }

    nonisolated static func estimatedItemWidth(containerWidth: CGFloat, traitCollection: UITraitCollection) -> CGFloat {
        let columns = CGFloat(columns(for: traitCollection))
        let horizontalInsets = sectionInsets.leading + sectionInsets.trailing
        let totalInterItemSpacing = max(columns - 1, 0) * interItemSpacing
        let availableWidth = containerWidth - horizontalInsets - totalInterItemSpacing
        return max(floor(availableWidth / columns), 1)
    }

    nonisolated static func canonicalImageTargetWidth(containerWidth: CGFloat) -> CGFloat {
        let horizontalInsets = sectionInsets.leading + sectionInsets.trailing
        let availableWidth = containerWidth - horizontalInsets
        return max(floor(availableWidth), 1)
    }

    nonisolated static func estimatedImageCellHeight(
        containerWidth: CGFloat,
        traitCollection: UITraitCollection
    ) -> CGFloat {
        let itemWidth = estimatedItemWidth(containerWidth: containerWidth, traitCollection: traitCollection)
        let imageHeight = itemWidth * imageAspectRatio
        return ceil(imageHeight + imageTextSpacing + imageTextBlockEstimatedHeight + imageCellVerticalInsets)
    }
}
