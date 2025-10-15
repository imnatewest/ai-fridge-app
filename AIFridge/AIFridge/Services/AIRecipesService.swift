//
//  AIRecipesService.swift
//  AIFridge
//
//  Created by Nathan West on 10/17/25.
//

import Foundation

actor AIRecipesService {
    static let shared = AIRecipesService()

    struct RecipeResult {
        let recipes: [RecipeSummary]
        let usedFallback: Bool
    }

    private enum Configuration {
        static let apiKeyInfoKey = "OPENAI_API_KEY"
        static let modelInfoKey = "OPENAI_MODEL"
        static let defaultModel = "gpt-4.1-mini"
        static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        static let maxRecipes = 6
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func generateRecipes(query: String?, inventory: [Item], limit: Int = Configuration.maxRecipes) async -> RecipeResult {
        let clampedLimit = max(1, min(limit, Configuration.maxRecipes))

        guard let apiKey = resolveAPIKey() else {
            return RecipeResult(recipes: fallbackRecipes(limit: clampedLimit), usedFallback: true)
        }

        do {
            let requestBody = OpenAIChatRequest(
                model: resolveModelName(),
                messages: [
                    .system("""
You are a culinary assistant that designs recipes using the ingredients provided from a smart fridge inventory. Generate approachable meal ideas that minimise waste and highlight fresh items.
"""),
                    .user(prompt(for: query, inventory: inventory, limit: clampedLimit))
                ],
                responseFormat: .jsonObject
            )

            var request = URLRequest(url: Configuration.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try encoder.encode(requestBody)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return RecipeResult(recipes: fallbackRecipes(limit: clampedLimit), usedFallback: true)
            }

            let chatResponse = try decoder.decode(OpenAIChatResponse.self, from: data)

            guard let content = chatResponse.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else {
                return RecipeResult(recipes: fallbackRecipes(limit: clampedLimit), usedFallback: true)
            }

            let payload = try decoder.decode(OpenAIRecipePayload.self, from: jsonData)
            let recipes = payload.recipes.map { $0.toRecipeSummary() }

            if recipes.isEmpty {
                return RecipeResult(recipes: fallbackRecipes(limit: clampedLimit), usedFallback: true)
            }

            return RecipeResult(recipes: recipes, usedFallback: false)
        } catch {
            print("❌ AIRecipesService error: \(error)")
            return RecipeResult(recipes: fallbackRecipes(limit: clampedLimit), usedFallback: true)
        }
    }
}

// MARK: - Helpers
private extension AIRecipesService {
    func resolveAPIKey() -> String? {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: Configuration.apiKeyInfoKey) as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue
        }

        if let envValue = ProcessInfo.processInfo.environment[Configuration.apiKeyInfoKey],
           !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envValue
        }

        return nil
    }

    func resolveModelName() -> String {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: Configuration.modelInfoKey) as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue
        }

        if let envValue = ProcessInfo.processInfo.environment[Configuration.modelInfoKey],
           !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envValue
        }

        return Configuration.defaultModel
    }

    func prompt(for query: String?, inventory: [Item], limit: Int) -> String {
        var lines: [String] = []
        lines.append("Available ingredients in the fridge:")

        if inventory.isEmpty {
            lines.append("- (No inventory items provided. Suggest versatile recipes using pantry staples.)")
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium

            for item in inventory {
                let quantityString: String
                if item.quantity == floor(item.quantity) {
                    quantityString = String(Int(item.quantity))
                } else {
                    quantityString = String(format: "%.2f", item.quantity)
                }

                let category = item.category?.isEmpty == false ? " • Category: \(item.category!)" : ""
                let expiration = formatter.string(from: item.expirationDate)
                lines.append("- \(item.name) — \(quantityString) \(item.unit)\(category) • Expires: \(expiration)")
            }
        }

        lines.append("")

        if let query, !query.isEmpty {
            lines.append("User preference: \(query)")
        } else {
            lines.append("User preference: Surprise the user with practical ideas that use the freshest items.")
        }

        lines.append("")
        lines.append("Respond with a JSON object containing a `recipes` array (up to \(limit) items). Each recipe should include:")
        lines.append("- `id` (UUID string, optional).")
        lines.append("- `title` (string).")
        lines.append("- `durationMinutes` (integer).")
        lines.append("- `usedItems` (array of strings from the inventory).")
        lines.append("- `missingItems` (array of strings).")
        lines.append("- `ingredients` (array of strings with quantities).")
        lines.append("- `instructions` (array of strings, each describing a step).")
        lines.append("- `imageURL` (optional string URL pointing to a royalty-free image).")
        lines.append("")
        lines.append("Do not include any text outside of the JSON object.")

        return lines.joined(separator: "\n")
    }

    func fallbackRecipes(limit: Int) -> [RecipeSummary] {
        Array(sampleRecipes.prefix(limit))
    }
}

// MARK: - OpenAI Models
private struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String

        static func system(_ content: String) -> Self { .init(role: "system", content: content) }
        static func user(_ content: String) -> Self { .init(role: "user", content: content) }
    }

    struct ResponseFormat: Encodable {
        let type: String

        static let jsonObject = ResponseFormat(type: "json_object")

        enum CodingKeys: String, CodingKey {
            case type
        }
    }

    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIRecipePayload: Decodable {
    let recipes: [OpenAIRecipe]
}

private struct OpenAIRecipe: Decodable {
    let id: String?
    let title: String
    let durationMinutes: Int?
    let usedItems: [String]?
    let missingItems: [String]?
    let ingredients: [String]
    let instructions: [String]
    let imageURL: URL?

    func toRecipeSummary() -> RecipeSummary {
        let uuid = id.flatMap(UUID.init) ?? UUID()
        let usedCount = usedItems?.count ?? 0
        let missingCount = missingItems?.count ?? 0
        let durationText = durationMinutes.flatMap { "\($0) min" }

        return RecipeSummary(
            id: uuid,
            title: title,
            imageURL: imageURL,
            usedCount: usedCount,
            missingCount: missingCount,
            durationText: durationText,
            ingredients: ingredients,
            instructions: instructions,
            missingItems: missingItems
        )
    }
}

// MARK: - Fallback Data
private let sampleRecipes: [RecipeSummary] = [
    RecipeSummary(
        id: UUID(),
        title: "Creamy Lemon Pasta with Spinach",
        imageURL: nil,
        usedCount: 3,
        missingCount: 1,
        durationText: "25 min",
        ingredients: [
            "200g linguine",
            "1 lemon",
            "2 cups spinach",
            "¼ cup grated parmesan",
            "2 cloves garlic"
        ],
        instructions: [
            "Cook pasta until al dente and reserve half a cup of pasta water.",
            "Sauté garlic in olive oil, add lemon zest and juice.",
            "Toss pasta with sauce, spinach, parmesan, and pasta water until creamy."
        ],
        missingItems: ["Parmesan cheese"]
    ),
    RecipeSummary(
        id: UUID(),
        title: "Sheet Pan Salmon & Veggies",
        imageURL: nil,
        usedCount: 4,
        missingCount: 0,
        durationText: "30 min",
        ingredients: [
            "2 salmon fillets",
            "1 cup cherry tomatoes",
            "1 zucchini",
            "1 red onion",
            "2 tbsp olive oil"
        ],
        instructions: [
            "Preheat oven to 400°F (200°C).",
            "Toss vegetables with olive oil and spread on sheet pan.",
            "Add salmon, season, and roast for 16-18 minutes."
        ],
        missingItems: []
    ),
    RecipeSummary(
        id: UUID(),
        title: "Spiced Chickpea Buddha Bowl",
        imageURL: nil,
        usedCount: 5,
        missingCount: 2,
        durationText: "35 min",
        ingredients: [
            "1 can chickpeas",
            "2 cups cooked quinoa",
            "1 avocado",
            "Mixed greens",
            "Tahini dressing"
        ],
        instructions: [
            "Roast chickpeas with spices until crispy.",
            "Assemble bowls with quinoa, greens, roasted chickpeas, and sliced avocado.",
            "Drizzle with tahini dressing."
        ],
        missingItems: ["Tahini", "Avocado"]
    )
]
