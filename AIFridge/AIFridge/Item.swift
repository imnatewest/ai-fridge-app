//
//  Item.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import Foundation
import FirebaseFirestoreSwift

struct Item: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var name: String
    var category: String?
    var quantity: Double
    var unit: String
    var expirationDate: Date
    var timestamp: Date
    // Open Food Facts / product metadata
    var barcode: String?
    var brand: String?

    // Serving info (e.g., 1, "cup" or 100, "g")
    var servingSizeValue: Double?
    var servingSizeUnit: String?

    struct Nutrition: Codable {
        // Common nutrients
        var calories: Double?
        var fat: Double?
        var carbs: Double?
        var protein: Double?

        // Optional dictionary for full nutrition facts if needed
        var raw: [String: Double]?
    }

    // Nutrition per 100g and per serving when available
    var nutritionPer100g: Nutrition?
    var nutritionPerServing: Nutrition?
}
