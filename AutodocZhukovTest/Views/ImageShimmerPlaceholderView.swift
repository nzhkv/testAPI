//
//  ImageShimmerPlaceholderView.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

final class ImageShimmerPlaceholderView: UIView {
    private let gradientLayer = CAGradientLayer()
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.35)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.65)
        layer.addSublayer(gradientLayer)
        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            guard self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else {
                return
            }
            self.updateColors()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutGradient()
    }

    func startAnimating() {
        guard !isAnimating, bounds.width > 0 else { return }
        isAnimating = true
        isHidden = false
        layoutGradient()

        let travel = bounds.width * 2
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -travel
        animation.toValue = travel
        animation.duration = 1.1
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "shimmer")
    }

    func stopAnimating() {
        isAnimating = false
        gradientLayer.removeAnimation(forKey: "shimmer")
    }

    private func layoutGradient() {
        let bandWidth = max(bounds.width * 0.55, 1)
        gradientLayer.frame = CGRect(
            x: -bandWidth,
            y: 0,
            width: bandWidth,
            height: bounds.height
        )
    }

    private func updateColors() {
        let base = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
                : UIColor(red: 0.86, green: 0.87, blue: 0.89, alpha: 1)
        }

        let highlight = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor.white.withAlphaComponent(0.65)
        }

        backgroundColor = base
        gradientLayer.colors = [
            base.withAlphaComponent(0).cgColor,
            highlight.cgColor,
            base.withAlphaComponent(0).cgColor
        ]
        gradientLayer.locations = [0.35, 0.5, 0.65]
    }
}
