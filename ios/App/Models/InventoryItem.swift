import Foundation
import FirebaseFirestoreSwift

struct NutritionInfo: Codable, Equatable {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var unit: String?

    var isEmpty: Bool {
        calories == nil && protein == nil && carbs == nil && fat == nil && unit == nil
    }
}

struct InventoryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var barcode: String?
    var category: String
    var quantity: Double
    var unit: String
    var expirationDate: Date?
    var nutrition: NutritionInfo?
    var timestamp: Date
    var householdID: String
    var createdBy: String?
    var updatedBy: String?

    init(
        id: String? = nil,
        name: String,
        barcode: String? = nil,
        category: String = "Uncategorized",
        quantity: Double = 1,
        unit: String = "pcs",
        expirationDate: Date? = nil,
        nutrition: NutritionInfo? = nil,
        timestamp: Date = Date(),
        householdID: String,
        createdBy: String? = nil,
        updatedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.expirationDate = expirationDate
        self.nutrition = nutrition?.isEmpty == true ? nil : nutrition
        self.timestamp = timestamp
        self.householdID = householdID
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Calendar.current.startOfDay(for: Date())
    }

    func expiresInDays(reference: Date = Date()) -> Int? {
        guard let expirationDate else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: reference)
        let startOfExpiration = Calendar.current.startOfDay(for: expirationDate)
        let components = Calendar.current.dateComponents([.day], from: startOfToday, to: startOfExpiration)
        return components.day
    }
}

extension InventoryItem {
    static var placeholder: InventoryItem {
        InventoryItem(name: "Sample Item", category: "Uncategorized", householdID: "demo")
    }
}
