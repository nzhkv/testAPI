//
//  NewsTextCell.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class NewsTextCell: UICollectionViewCell {
    static let reuseIdentifier = "NewsTextCell"

    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let readBadge = NewsReadBadgeView()
    private let textStack: UIStackView
    private var pinnedTextConstraints: [NSLayoutConstraint] = []
    private var centeredTextConstraints: [NSLayoutConstraint] = []
    private var centersTextVertically = false

    override init(frame: CGRect) {
        textStack = NewsCellStyle.makeTextStack(
            categoryLabel: categoryLabel,
            titleLabel: titleLabel
        )
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        categoryLabel.text = nil
        readBadge.setVisible(false)
        setCentersTextVertically(false)
    }

    func configure(with item: NewsItem, isRead: Bool, centersTextVertically: Bool = false) {
        titleLabel.text = item.title
        categoryLabel.text = item.category
        readBadge.setVisible(isRead)
        setCentersTextVertically(centersTextVertically)
    }

    private func setupView() {
        NewsCellStyle.applyCardStyle(to: contentView)
        NewsCellStyle.applyTitleStyle(to: titleLabel, numberOfLines: 0)
        NewsCellStyle.applyCategoryStyle(to: categoryLabel)

        textStack.translatesAutoresizingMaskIntoConstraints = false
        readBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)
        contentView.addSubview(readBadge)

        let insets = NewsCellStyle.textCellInsets
        pinnedTextConstraints = [
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: insets.top),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.leading),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.trailing),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -insets.bottom)
        ]
        centeredTextConstraints = [
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.leading),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.trailing)
        ]

        NSLayoutConstraint.activate(pinnedTextConstraints)
        NSLayoutConstraint.activate([
            readBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            readBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        ])
    }

    private func setCentersTextVertically(_ centersTextVertically: Bool) {
        guard self.centersTextVertically != centersTextVertically else { return }

        self.centersTextVertically = centersTextVertically
        NSLayoutConstraint.deactivate(centersTextVertically ? pinnedTextConstraints : centeredTextConstraints)
        NSLayoutConstraint.activate(centersTextVertically ? centeredTextConstraints : pinnedTextConstraints)
    }
}
