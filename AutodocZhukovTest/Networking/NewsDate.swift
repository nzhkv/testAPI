//
//  NewsDate.swift
//  AutodocZhukovTest
//
//  Created by Nikolai Zhukov on 27/05/2026.
//

import Foundation

enum NewsDateDecoder {
    private static let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from rawValue: String) -> Date? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let date = iso8601Formatter.date(from: trimmedValue) {
            return date
        }

        if let date = iso8601FormatterWithoutFractionalSeconds.date(from: trimmedValue) {
            return date
        }

        for formatter in formatters {
            if let date = formatter.date(from: trimmedValue) {
                return date
            }
        }

        return nil
    }
}

enum NewsDateFormatting {
    private static let listFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func listFormatted(_ date: Date) -> String {
        listFormatter.string(from: date)
    }
}
