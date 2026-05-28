//
//  NewsCellStyle.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

enum NewsCellStyle {
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1
    static let borderColor = UIColor.separator
    static let textSpacing: CGFloat = 6
    static let imageTextSpacing: CGFloat = 12
    static let imageAspectRatio: CGFloat = 9.0 / 16.0
    static let imageCellInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    static let textCellInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)

    static func applyCardStyle(to contentView: UIView) {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.borderWidth = borderWidth
        contentView.layer.borderColor = borderColor.cgColor
        contentView.layer.masksToBounds = true
    }

    static func applyTitleStyle(to label: UILabel, numberOfLines: Int) {
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = numberOfLines
        label.adjustsFontForContentSizeCategory = true
    }

    static func applyCategoryStyle(to label: UILabel) {
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
    }

    static func applyImageStyle(to imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
    }

    static func makeTextStack(categoryLabel: UILabel, titleLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [categoryLabel, titleLabel])
        stackView.axis = .vertical
        stackView.spacing = textSpacing
        return stackView
    }
}
