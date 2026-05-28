//
//  NewsCacheStore.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

protocol NewsCacheStoreProtocol: Sendable {
    func loadFirstPage() async -> NewsPage?
    func saveFirstPage(_ page: NewsPage) async
}

actor NewsCacheStore: NewsCacheStoreProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directoryURL = baseURL.appending(path: "NewsCache", directoryHint: .isDirectory)
        self.fileURL = directoryURL.appending(path: "first-page.json")

        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadFirstPage() async -> NewsPage? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(NewsPage.self, from: data)
        } catch {
            return nil
        }
    }

    func saveFirstPage(_ page: NewsPage) async {
        do {
            let data = try encoder.encode(page)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }
}
