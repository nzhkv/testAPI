//
//  NewsItem.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

nonisolated struct NewsItem: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    let description: String
    let publishedDate: Date?
    let titleImageURL: URL?
    let category: String
}

nonisolated struct NewsPage: Codable, Equatable, Sendable {
    let items: [NewsItem]
    let totalCount: Int
}
