//
//  ImagePreheater.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

enum ImagePreheater {
    nonisolated static let defaultBatchSize = 6

    static func preheat(
        items: [NewsItem],
        imageLoader: any ImageLoaderProtocol,
        targetWidth: CGFloat,
        scale: CGFloat,
        maxImageCount: Int? = nil,
        batchSize: Int = defaultBatchSize,
        priority: ImageLoadPriority = .background
    ) async {
        var imageURLs = uniqueImageURLs(from: items)
        if let maxImageCount {
            imageURLs = Array(imageURLs.prefix(maxImageCount))
        }

        let effectiveBatchSize = max(batchSize, 1)

        for batchStartIndex in stride(from: 0, to: imageURLs.count, by: effectiveBatchSize) {
            guard !Task.isCancelled else { return }

            let batchEndIndex = min(batchStartIndex + effectiveBatchSize, imageURLs.count)
            let batch = Array(imageURLs[batchStartIndex..<batchEndIndex])

            await withTaskGroup(of: Void.self) { group in
                for imageURL in batch {
                    guard !Task.isCancelled else { return }

                    group.addTask(priority: .utility) {
                        _ = try? await imageLoader.image(
                            for: imageURL,
                            targetWidth: targetWidth,
                            scale: scale,
                            priority: priority
                        )
                    }
                }
            }
        }
    }

    private static func uniqueImageURLs(from items: [NewsItem]) -> [URL] {
        var seenURLs = Set<URL>()

        return items.compactMap { item in
            guard
                let imageURL = item.titleImageURL,
                !seenURLs.contains(imageURL)
            else {
                return nil
            }

            seenURLs.insert(imageURL)
            return imageURL
        }
    }
}
