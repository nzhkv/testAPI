//
//  ImageLoader.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import ImageIO
import UIKit

enum ImageLoadPriority: Sendable {
    case display
    case background
}

protocol ImageLoaderProtocol: Sendable {
    func cachedImage(for url: URL) async -> UIImage?
    func image(
        for url: URL,
        targetWidth: CGFloat,
        scale: CGFloat,
        priority: ImageLoadPriority
    ) async throws -> UIImage
}

extension ImageLoaderProtocol {
    func image(for url: URL, targetWidth: CGFloat, scale: CGFloat) async throws -> UIImage {
        try await image(for: url, targetWidth: targetWidth, scale: scale, priority: .display)
    }
}

actor ImageLoader: ImageLoaderProtocol {
    static let shared = ImageLoader()

    private nonisolated static let retryCooldown: TimeInterval = 25
    private nonisolated static let imageAspectRatio: CGFloat = 9.0 / 16.0

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var failedUntil: [NSString: Date] = [:]
    private var inFlightTasks: [NSString: Task<UIImage, Error>] = [:]

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpMaximumConnectionsPerHost = 6
            configuration.timeoutIntervalForRequest = 15
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func cachedImage(for url: URL) async -> UIImage? {
        cache.object(forKey: Self.urlCacheKey(for: url))
    }

    func image(
        for url: URL,
        targetWidth: CGFloat,
        scale: CGFloat,
        priority: ImageLoadPriority
    ) async throws -> UIImage {
        if cache.countLimit != 120 {
            cache.countLimit = 120
        }

        let normalizedWidth = Self.normalizedTargetWidth(targetWidth)
        let targetSize = CGSize(
            width: normalizedWidth,
            height: normalizedWidth * Self.imageAspectRatio
        )
        let maxPixelSize = max(
            Int(ceil(targetSize.width * scale)),
            Int(ceil(targetSize.height * scale))
        )
        let urlCacheKey = Self.urlCacheKey(for: url)
        let failureKey = Self.failureKey(for: url)

        if let cachedImage = cache.object(forKey: urlCacheKey) {
            return cachedImage
        }

        if let retryDate = failedUntil[failureKey] {
            if retryDate > Date() {
                throw ImageLoaderError.cooldown
            } else {
                failedUntil[failureKey] = nil
            }
        }

        if let inFlightTask = inFlightTasks[urlCacheKey] {
            return try await inFlightTask.value
        }

        let session = self.session
        let taskPriority: TaskPriority = switch priority {
        case .display: .userInitiated
        case .background: .utility
        }
        let task = Task.detached(priority: taskPriority) {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageLoaderError.invalidImageData
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ImageLoaderError.httpStatus(httpResponse.statusCode)
            }

            return try Self.downsampleImage(data: data, maxPixelSize: maxPixelSize, scale: scale)
        }

        inFlightTasks[urlCacheKey] = task

        do {
            let image = try await task.value
            cache.setObject(image, forKey: urlCacheKey)
            failedUntil[failureKey] = nil
            inFlightTasks[urlCacheKey] = nil
            return image
        } catch {
            inFlightTasks[urlCacheKey] = nil
            rememberFailure(for: failureKey, error: error)
            throw error
        }
    }

    private func rememberFailure(for key: NSString, error: Error) {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return
        }

        if error is CancellationError {
            return
        }

        failedUntil[key] = Date().addingTimeInterval(Self.retryCooldown)
    }

    private nonisolated static func normalizedTargetWidth(_ width: CGFloat) -> CGFloat {
        max(floor(width), 1)
    }

    private nonisolated static func downsampleImage(data: Data, maxPixelSize: Int, scale: CGFloat) throws -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard
            let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
        else {
            throw ImageLoaderError.invalidImageData
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private nonisolated static func urlCacheKey(for url: URL) -> NSString {
        url.absoluteString as NSString
    }

    private nonisolated static func failureKey(for url: URL) -> NSString {
        url.absoluteString as NSString
    }
}

enum ImageLoaderError: Error {
    case invalidImageData
    case httpStatus(Int)
    case cooldown
}
