//
//  NewsAPIClient.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

protocol NewsAPIClientProtocol {
    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage
}

final class NewsAPIClient: NewsAPIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://webapi.autodoc.ru/api")!,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 15
            self.session = URLSession(configuration: configuration)
        }
        self.decoder = JSONDecoder()
    }

    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage {
        let url = baseURL
            .appending(path: "news")
            .appending(path: String(page))
            .appending(path: String(pageSize))

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NewsAPIError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(NewsPageDTO.self, from: data).asDomain
        } catch {
            throw NewsAPIError.decoding(error)
        }
    }
}

enum NewsAPIError: Error {
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)
}

private struct NewsPageDTO: Decodable {
    let news: [NewsDTO]
    let totalCount: Int

    var asDomain: NewsPage {
        NewsPage(
            items: news.map(\.asDomain),
            totalCount: totalCount
        )
    }
}

private struct NewsDTO: Decodable {
    let id: Int
    let title: String
    let description: String?
    let publishedDate: Date?
    let titleImageUrl: String?
    let categoryType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case publishedDate
        case titleImageUrl
        case categoryType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        publishedDate = Self.decodePublishedDate(from: container)
        titleImageUrl = try container.decodeIfPresent(String.self, forKey: .titleImageUrl)
        categoryType = try container.decodeIfPresent(String.self, forKey: .categoryType)
    }

    var asDomain: NewsItem {
        NewsItem(
            id: id,
            title: title,
            description: description ?? "",
            publishedDate: publishedDate,
            titleImageURL: titleImageUrl.flatMap(URL.init(string:)),
            category: categoryType ?? ""
        )
    }

    private static func decodePublishedDate(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        if let dateString = try? container.decode(String.self, forKey: .publishedDate) {
            return NewsDateDecoder.date(from: dateString)
        }

        if let timestamp = try? container.decode(Double.self, forKey: .publishedDate) {
            return Date(timeIntervalSince1970: timestamp)
        }

        return nil
    }
}
