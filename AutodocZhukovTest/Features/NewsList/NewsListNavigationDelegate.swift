//
//  NewsListNavigationDelegate.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

@MainActor
protocol NewsListNavigationDelegate: AnyObject {
    func newsList(_ newsList: NewsListViewController, didSelect item: NewsItem)
}
