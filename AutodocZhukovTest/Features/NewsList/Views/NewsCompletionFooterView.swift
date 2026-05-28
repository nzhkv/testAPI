//
//  NewsCompletionFooterView.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class NewsCompletionFooterView: UICollectionReusableView {
    static let reuseIdentifier = "NewsCompletionFooterView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isVisible: Bool) {
        label.isHidden = !isVisible
    }

    private func setupView() {
        label.text = "Вы отлично потрудились, все новости прочитаны"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }
}
