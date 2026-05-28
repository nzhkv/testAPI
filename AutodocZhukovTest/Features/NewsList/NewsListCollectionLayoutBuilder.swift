//
//  NewsListCollectionLayoutBuilder.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

enum NewsListCollectionLayoutBuilder {
    static func makeLayout(
        columnsProvider: @escaping (UITraitCollection) -> Int,
        showsCompletionFooter: @escaping () -> Bool
    ) -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let columns = columnsProvider(layoutEnvironment.traitCollection)
            let columnFraction = 1.0 / CGFloat(columns)
            let containerWidth = layoutEnvironment.container.effectiveContentSize.width
            let traitCollection = layoutEnvironment.traitCollection
            let usesUniformRowHeights = columns > 1
            let estimatedImageHeight = NewsListLayoutMetrics.estimatedImageCellHeight(
                containerWidth: containerWidth,
                traitCollection: traitCollection
            )

            let itemHeightDimension: NSCollectionLayoutDimension = usesUniformRowHeights
                ? .fractionalHeight(1.0)
                : .estimated(estimatedImageHeight)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(columnFraction),
                heightDimension: itemHeightDimension
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimatedImageHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columns
            )
            group.interItemSpacing = .fixed(NewsListLayoutMetrics.interItemSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NewsListLayoutMetrics.sectionInsets
            section.interGroupSpacing = NewsListLayoutMetrics.interGroupSpacing

            if showsCompletionFooter() {
                section.boundarySupplementaryItems = [makeCompletionFooterItem()]
            }

            return section
        }
    }

    private static func makeCompletionFooterItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(72)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
    }
}
