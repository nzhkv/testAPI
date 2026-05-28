//
//  NewsReadStatusManager.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Combine
import Foundation

@MainActor
final class NewsReadStatusManager {
    @Published private(set) var readIDs: Set<Int> = []

    private let store: NewsReadStoreProtocol
    private var hasLoaded = false
    private var saveTask: Task<Void, Never>?

    init(store: NewsReadStoreProtocol) {
        self.store = store
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }

        readIDs = await store.loadReadIDs()
        hasLoaded = true
    }

    func isRead(_ id: Int) -> Bool {
        readIDs.contains(id)
    }

    func markAsRead(_ id: Int) {
        guard readIDs.insert(id).inserted else { return }

        saveTask?.cancel()
        let ids = readIDs
        saveTask = Task {
            await store.saveReadIDs(ids)
        }
    }
}
