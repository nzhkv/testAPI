//
//  NetworkPathMonitor.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation
import Network

@MainActor
protocol NetworkStatusMonitoring: AnyObject {
    var isConnected: Bool { get }
    func start()
    func setStatusHandler(_ handler: @escaping (Bool) -> Void)
}

@MainActor
final class NetworkPathMonitor: NetworkStatusMonitoring {
    static let shared = NetworkPathMonitor()

    private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private var statusHandler: ((Bool) -> Void)?
    private var didStart = false

    func start() {
        guard !didStart else { return }
        didStart = true

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?.scheduleConnectionStatusUpdate(connected)
        }
        monitor.start(queue: DispatchQueue(label: "NetworkPathMonitor"))
        applyConnectionStatus(monitor.currentPath.status == .satisfied)
    }

    nonisolated private func scheduleConnectionStatusUpdate(_ connected: Bool) {
        Task { @MainActor [weak self] in
            self?.applyConnectionStatus(connected)
        }
    }

    private func applyConnectionStatus(_ connected: Bool) {
        let changed = isConnected != connected
        isConnected = connected
        if changed {
            statusHandler?(connected)
        }
    }

    func setStatusHandler(_ handler: @escaping (Bool) -> Void) {
        statusHandler = handler
        handler(isConnected)
    }
}
