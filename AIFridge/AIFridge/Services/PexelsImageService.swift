//
//  PexelsImageService.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import Foundation

enum IngredientImageError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing Pexels API key. Add `PEXELS_API_KEY` to Info.plist."
        case .invalidResponse: return "Unable to decode image from Pexels response."
        }
    }
}

final class PexelsImageService {
    static let shared = PexelsImageService()

    private let session: URLSession
    private let cache = NSCache<NSString, NSURL>()
    private var emptyResults = Set<String>()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    enum ImageSize: String {
        case small
        case medium
        case large
    }

    func thumbnailURL(for query: String, size: ImageSize = .small) async throws -> URL? {
        let normalizedQuery = sanitize(query)

        if normalizedQuery.isEmpty {
            return nil
        }

        let cacheKey = cacheKey(for: normalizedQuery, size: size)

        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached as URL
        }

        if emptyResults.contains(cacheKey) {
            return nil
        }

        let apiKey = apiKeyFromBundle() ?? apiKeyFromEnvironment()

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IngredientImageError.missingAPIKey
        }

        if let url = try await performSearch(query: normalizedQuery, apiKey: apiKey, size: size) {
            cache.setObject(url as NSURL, forKey: cacheKey as NSString)
            return url
        }

        emptyResults.insert(cacheKey)
        return nil
    }

    private func sanitize(_ query: String) -> String {
        query
            .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func apiKeyFromBundle() -> String? {
        if let exact = Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String {
            return exact
        }
        if let alt = Bundle.main.object(forInfoDictionaryKey: "Pexels Api Key") as? String {
            return alt
        }
        return nil
    }

    private func apiKeyFromEnvironment() -> String {
        ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? ""
    }

    private func performSearch(query: String, apiKey: String, size: ImageSize) async throws -> URL? {
        var components = URLComponents(string: "https://api.pexels.com/v1/search")!
        var enrichedQuery = query

        var items: [URLQueryItem] = [
            URLQueryItem(name: "query", value: enrichedQuery),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "orientation", value: "square"),
            URLQueryItem(name: "size", value: size.rawValue)
        ]

        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw IngredientImageError.invalidResponse
        }

        if http.statusCode == 429 {
            throw IngredientImageError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            return nil
        }

        let result = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
        guard let first = result.photos.first,
              let url = preferredURL(from: first.src, size: size) else {
            return nil
        }

        return url
    }

    private func preferredURL(from src: PexelsSearchResponse.Photo.ImageSources, size: ImageSize) -> URL? {
        let candidates: [String?]
        switch size {
        case .small:
            candidates = [src.small, src.medium, src.large, src.original]
        case .medium:
            candidates = [src.medium, src.large, src.original, src.small]
        case .large:
            candidates = [src.large, src.original, src.medium, src.small]
        }

        for candidate in candidates {
            if let string = candidate, let url = URL(string: string) {
                return url
            }
        }
        return nil
    }

    private func cacheKey(for query: String, size: ImageSize) -> String {
        "\(query)|\(size.rawValue)"
    }
}

// MARK: - Response models
private struct PexelsSearchResponse: Decodable {
    let photos: [Photo]

    struct Photo: Decodable {
        struct ImageSources: Decodable {
            let original: String?
            let large: String?
            let medium: String?
            let small: String?
        }

        let src: ImageSources
    }
}
