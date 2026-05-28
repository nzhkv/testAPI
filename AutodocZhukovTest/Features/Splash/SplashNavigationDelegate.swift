//
//  SplashNavigationDelegate.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

@MainActor
protocol SplashNavigationDelegate: AnyObject {
    func splashDidFinish(viewModel: NewsListViewModel)
}
