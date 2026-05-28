//
//  NewsReadStore.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

protocol NewsReadStoreProtocol: Sendable {
    func loadReadIDs() async -> Set<Int>
    func saveReadIDs(_ ids: Set<Int>) async
}

actor NewsReadStore: NewsReadStoreProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directoryURL = baseURL.appending(path: "NewsCache", directoryHint: .isDirectory)
        self.fileURL = directoryURL.appending(path: "read-news-ids.json")

        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        encoder.outputFormatting = [.sortedKeys]
    }

    func loadReadIDs() async -> Set<Int> {
        do {
            let data = try Data(contentsOf: fileURL)
            let cache = try decoder.decode(NewsReadIDsCache.self, from: data)
            return cache.ids
        } catch {
            return []
        }
    }

    func saveReadIDs(_ ids: Set<Int>) async {
        do {
            let cache = NewsReadIDsCache(ids: ids)
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }
}

private nonisolated struct NewsReadIDsCache: Codable {
    let ids: Set<Int>
}
