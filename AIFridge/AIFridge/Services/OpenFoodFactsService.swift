//
//  OpenFoodFactsService.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import Foundation

/// A small decoding helper that accepts either numeric or string values for numbers in API responses.
struct FlexibleDouble: Decodable, Sendable {
    /// The parsed value when a numeric value could be obtained, otherwise nil.
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
            return
        }

        if let doubleVal = try? container.decode(Double.self) {
            self.value = doubleVal
            return
        }

        if let stringVal = try? container.decode(String.self) {
            // Try to parse localized decimal separators; if unparsable, return nil instead of failing
            let cleaned = stringVal.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Double(cleaned) {
                self.value = parsed
            } else {
                self.value = nil
            }
            return
        }

        // If it's some other type we don't understand, return nil
        self.value = nil
    }
}

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

        do {
            let payload = try decoder.decode(OpenFoodFactsResponse.self, from: data)
            let product = payload.status == 1 ? payload.product : nil
            cache[sanitized] = product
            return product
        } catch {
            // Provide a clearer error message including a short snippet of the response to help debugging
            let snippetLimit = 2000
            let rawText = String(data: data, encoding: .utf8) ?? "<binary or non-utf8 response>"
            let snippet = rawText.count > snippetLimit ? String(rawText.prefix(snippetLimit)) + "…" : rawText
            let userInfo: [String: Any] = [NSLocalizedDescriptionKey: "Decoding OpenFoodFacts response failed: \(error.localizedDescription). Response snippet: \(snippet)"]
            throw NSError(domain: "OpenFoodFactsService", code: 1001, userInfo: userInfo)
        }
    }

    /// Build a partial Item from an OpenFoodFactsProduct. This does not save to Firestore.
    nonisolated func itemFromProduct(_ product: OpenFoodFactsProduct, barcode: String? = nil) -> Item {
        let name = product.preferredProductName ?? product.displayName ?? product.primaryCategory ?? "Unknown"
        let category = product.primaryCategory
        let brand = product.primaryBrand

        let parsedQuantity = product.parsedQuantity
        let quantityValue = parsedQuantity?.amount ?? 1
        let quantityUnit = parsedQuantity?.unit ?? "pc"

        var item = Item(id: nil,
                        name: name,
                        category: category,
                        quantity: quantityValue,
                        unit: quantityUnit,
                        expirationDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
                        timestamp: Date(),
                        barcode: barcode,
                        brand: brand,
                        servingSizeValue: nil,
                        servingSizeUnit: nil,
                        nutritionPer100g: nil,
                        nutritionPerServing: nil)

        // parse serving size if available
        if let parsedServing = product.parsedServingSize {
            item.servingSizeValue = parsedServing.value
            item.servingSizeUnit = parsedServing.unit
        }

        // map nutrition
        if let n100 = product.nutritionPer100g() {
            item.nutritionPer100g = n100
        }
        if let nServing = product.nutritionPerServing() {
            item.nutritionPerServing = nServing
        }

        return item
    }
}

struct OpenFoodFactsProduct: Decodable, Sendable {
    let productName: String?
    let genericName: String?
    let brands: String?
    let categoriesTags: [String]?
    let quantity: String?
    let servingSize: String?
    // Nutriments in the API sometimes come back as numbers or strings -> decode flexibly
    let nutriments: [String: FlexibleDouble]?
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

    var preferredProductName: String? {
        let nameCandidates = [productName, genericName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstCandidate = nameCandidates.first else {
            return nil
        }

        if let brand = primaryBrand,
           firstCandidate.caseInsensitiveCompare(brand) == .orderedSame {
            if nameCandidates.count > 1 {
                return nameCandidates[1]
            }

            if let category = primaryCategory {
                return "\(brand) \(category)"
            }
        }

        return firstCandidate
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

    /// Parse servingSize string like "30 g" or "1 cup (240 ml)" into a primary value and unit when possible
    var parsedServingSize: (value: Double, unit: String)? {
        guard let servingSize else { return nil }
        // Try to find first numeric value and following unit
        let cleaned = servingSize.replacingOccurrences(of: ",", with: ".")
        // Regex to capture number and unit
        if let regex = try? NSRegularExpression(pattern: "([0-9]+\\.?[0-9]*)\\s*([a-zA-Z%]+)", options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = regex.firstMatch(in: cleaned, options: [], range: range), match.numberOfRanges >= 3 {
                if let numRange = Range(match.range(at: 1), in: cleaned), let unitRange = Range(match.range(at: 2), in: cleaned) {
                    let numStr = String(cleaned[numRange])
                    let unitStr = String(cleaned[unitRange])
                    if let val = Double(numStr) {
                        return (val, unitStr.lowercased())
                    }
                }
            }
        }
        return nil
    }

    /// Convert nutriments dictionary into Item.Nutrition for per-100g values
    func nutritionPer100g() -> Item.Nutrition? {
        guard let n = nutriments else { return nil }
        var raw: [String: Double] = [:]
        // Helper to read value for multiple possible keys
        func value(for keys: [String]) -> Double? {
            for k in keys {
                if let v = n[k] { return v.value }
            }
            return nil
        }

        let calories = value(for: ["energy-kcal_100g", "energy_100g", "energy-kcal_value_100g"]) ?? value(for: ["energy-kcal_value"]) // fallback
        let fat = value(for: ["fat_100g", "fat_value_100g"])
        let carbs = value(for: ["carbohydrates_100g", "carbohydrates_value_100g", "carbohydrates_100g"])
        let protein = value(for: ["proteins_100g", "protein_100g", "proteins_value_100g"])

        // collect raw keys that exist
        for (k, v) in n {
            if let val = v.value { raw[k] = val }
        }

        if calories == nil && fat == nil && carbs == nil && protein == nil { return nil }

        return Item.Nutrition(calories: calories, fat: fat, carbs: carbs, protein: protein, raw: raw)
    }

    /// Convert nutriments dictionary into Item.Nutrition for per-serving values when available
    func nutritionPerServing() -> Item.Nutrition? {
        guard let n = nutriments else { return nil }
        var raw: [String: Double] = [:]
        func value(for keys: [String]) -> Double? {
            for k in keys {
                if let v = n[k] { return v.value }
            }
            return nil
        }

        let calories = value(for: ["energy-kcal_serving", "energy-kcal_serving_100g", "energy_serving", "energy-kcal_serving_value"]) ?? value(for: ["energy_serving"])
        let fat = value(for: ["fat_serving", "fat_value_serving"])
        let carbs = value(for: ["carbohydrates_serving", "carbohydrates_value_serving"])
        let protein = value(for: ["proteins_serving", "protein_serving", "proteins_value_serving"])

        for (k, v) in n {
            if let val = v.value { raw[k] = val }
        }

        if calories == nil && fat == nil && carbs == nil && protein == nil { return nil }

        return Item.Nutrition(calories: calories, fat: fat, carbs: carbs, protein: protein, raw: raw)
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: OpenFoodFactsProduct?
}
