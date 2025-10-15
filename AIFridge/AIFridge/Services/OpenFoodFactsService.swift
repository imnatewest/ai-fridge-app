//
//  OpenFoodFactsService.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import Foundation

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private var cache: [String: OpenFoodFactsProduct?] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(barcode: String) async throws -> OpenFoodFactsProduct? {
        let sanitized = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cached = cache[sanitized] {
            return cached
        }

        guard !sanitized.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(sanitized).json")
        else {
            cache[sanitized] = nil
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            cache[sanitized] = nil
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let payload = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        let product = payload.status == 1 ? payload.product : nil
        cache[sanitized] = product
        return product
    }
}

struct OpenFoodFactsProduct: Decodable, Sendable {
    let productName: String?
    let genericName: String?
    let brands: String?
    let categoriesTags: [String]?
    let quantity: String?
    let servingSize: String?
    let imageUrl: String?

    var displayName: String? {
        if let productName, !productName.isEmpty {
            return productName
        }
        if let genericName, !genericName.isEmpty {
            return genericName
        }
        return nil
    }

    var primaryCategory: String? {
        guard let categoriesTags, let first = categoriesTags.first else { return nil }
        return first
            .replacingOccurrences(of: "en:", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var primaryBrand: String? {
        guard let brands else { return nil }
        return brands
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var imageURL: URL? {
        guard let imageUrl, let url = URL(string: imageUrl) else { return nil }
        return url
    }

    var parsedQuantity: (amount: Double, unit: String)? {
        guard let quantity else { return nil }
        let components = quantity
            .replacingOccurrences(of: ",", with: ".")
            .split(separator: " ")

        guard let amountString = components.first,
              let amount = Double(amountString)
        else {
            return nil
        }

        let unit = components.dropFirst().joined(separator: " ").lowercased()
        return (amount, unit.isEmpty ? "pcs" : unit)
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: OpenFoodFactsProduct?
}
