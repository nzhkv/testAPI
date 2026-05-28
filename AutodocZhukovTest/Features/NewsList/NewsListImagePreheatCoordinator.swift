//
//  NewsListImagePreheatCoordinator.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import UIKit

@MainActor
final class NewsListImagePreheatCoordinator {
    private let imageLoader: any ImageLoaderProtocol
    private var imagePreheatTask: Task<Void, Never>?
    private var imagePreheatQueue: [NewsItem] = []
    private var queuedImagePreheatItemIDs = Set<Int>()
    private var completedImagePreheatItemIDs = Set<Int>()
    private var lastContainerWidth: CGFloat = 0
    private var lastScale: CGFloat = 2

    init(imageLoader: any ImageLoaderProtocol) {
        self.imageLoader = imageLoader
    }

    deinit {
        imagePreheatTask?.cancel()
    }

    func markPrefetched(itemIDs: [Int]) {
        itemIDs.forEach { completedImagePreheatItemIDs.insert($0) }
        itemIDs.forEach { queuedImagePreheatItemIDs.remove($0) }
        imagePreheatQueue.removeAll { itemIDs.contains($0.id) }
    }

    func enqueue(items: [NewsItem], containerWidth: CGFloat, scale: CGFloat) {
        guard containerWidth > 0 else { return }

        lastContainerWidth = containerWidth
        lastScale = scale

        let newItems = items.filter { item in
            guard item.titleImageURL != nil else { return false }
            return !completedImagePreheatItemIDs.contains(item.id)
                && !queuedImagePreheatItemIDs.contains(item.id)
        }

        guard !newItems.isEmpty else { return }

        newItems.forEach { queuedImagePreheatItemIDs.insert($0.id) }
        imagePreheatQueue.append(contentsOf: newItems)
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard imagePreheatTask == nil, lastContainerWidth > 0 else { return }

        let imageWidth = NewsListLayoutMetrics.canonicalImageTargetWidth(containerWidth: lastContainerWidth)
        let scale = lastScale
        let imageLoader = self.imageLoader
        let coordinator = self

        imagePreheatTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let workItem = await coordinator.nextPreheatWorkItem()

                guard let workItem else { return }

                if workItem.shouldStop {
                    return
                }

                let batch = workItem.batch

                await withTaskGroup(of: Int?.self) { group in
                    for item in batch {
                        guard let imageURL = item.titleImageURL else { continue }

                        group.addTask(priority: .utility) {
                            do {
                                _ = try await imageLoader.image(
                                    for: imageURL,
                                    targetWidth: imageWidth,
                                    scale: scale,
                                    priority: .background
                                )
                                return item.id
                            } catch {
                                return nil
                            }
                        }
                    }

                    for await itemID in group {
                        await coordinator.recordPreheatedItem(id: itemID)
                    }
                }

                await coordinator.clearQueuedIDs(for: batch)
            }
        }
    }

    private struct PreheatWorkItem: Sendable {
        let batch: [NewsItem]
        let shouldStop: Bool
    }

    private func nextPreheatWorkItem() -> PreheatWorkItem? {
        let batchCount = min(ImagePreheater.defaultBatchSize, imagePreheatQueue.count)
        guard batchCount > 0 else {
            imagePreheatTask = nil
            return PreheatWorkItem(batch: [], shouldStop: true)
        }

        let batch = Array(imagePreheatQueue.prefix(batchCount))
        imagePreheatQueue.removeFirst(batchCount)
        return PreheatWorkItem(batch: batch, shouldStop: false)
    }

    private func recordPreheatedItem(id: Int?) {
        guard let id else { return }
        completedImagePreheatItemIDs.insert(id)
        queuedImagePreheatItemIDs.remove(id)
    }

    private func clearQueuedIDs(for batch: [NewsItem]) {
        batch.forEach { queuedImagePreheatItemIDs.remove($0.id) }
    }
}
