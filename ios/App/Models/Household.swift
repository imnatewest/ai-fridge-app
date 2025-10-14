import Foundation
import FirebaseFirestoreSwift

enum InventorySortOption: String, Codable, CaseIterable, Identifiable {
    case expirationDate
    case name
    case category

    var id: String { rawValue }
    var localizedTitle: String {
        switch self {
        case .expirationDate: return "Expiration"
        case .name: return "Name"
        case .category: return "Category"
        }
    }
}

struct HouseholdSettings: Codable, Equatable {
    var defaultUnit: String
    var notificationsEnabled: Bool
    var lowStockThreshold: Double
}

struct HouseholdPreferences: Codable, Equatable {
    var defaultSort: InventorySortOption
    var expirationWarningDays: Int
    var favoriteCategories: [String]?
}

struct Household: Identifiable, Codable {
    @DocumentID var id: String?
    var members: [String]
    var settings: HouseholdSettings
    var preferences: HouseholdPreferences
    var createdAt: Date
    var updatedAt: Date
}

extension Household {
    static func makeDefault(for userID: String) -> Household {
        Household(
            id: userID,
            members: [userID],
            settings: HouseholdSettings(
                defaultUnit: "pcs",
                notificationsEnabled: true,
                lowStockThreshold: 0.2
            ),
            preferences: HouseholdPreferences(
                defaultSort: .expirationDate,
                expirationWarningDays: 3,
                favoriteCategories: nil
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
