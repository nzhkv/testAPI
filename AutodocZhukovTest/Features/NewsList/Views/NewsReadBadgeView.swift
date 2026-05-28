//
//  NewsReadBadgeView.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class NewsReadBadgeView: UIView {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setVisible(_ isVisible: Bool) {
        isHidden = !isVisible
    }

    private func setupView() {
        isUserInteractionEnabled = false
        isHidden = true

        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
        imageView.tintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
