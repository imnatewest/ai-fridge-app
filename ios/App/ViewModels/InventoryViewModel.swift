import Foundation
import Combine

struct InventoryDraft: Identifiable, Equatable {
    var id: String?
    var name: String
    var barcode: String
    var category: String
    var quantity: Double
    var unit: String
    var expirationDate: Date?
    var calories: String
    var protein: String
    var carbs: String
    var fat: String

    init(
        id: String? = nil,
        name: String = "",
        barcode: String = "",
        category: String = "Uncategorized",
        quantity: Double = 1,
        unit: String = "pcs",
        expirationDate: Date? = nil,
        calories: String = "",
        protein: String = "",
        carbs: String = "",
        fat: String = ""
    ) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.expirationDate = expirationDate
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(item: InventoryItem) {
        self.init(
            id: item.id,
            name: item.name,
            barcode: item.barcode ?? "",
            category: item.category,
            quantity: item.quantity,
            unit: item.unit,
            expirationDate: item.expirationDate,
            calories: item.nutrition?.calories.map { String($0) } ?? "",
            protein: item.nutrition?.protein.map { String($0) } ?? "",
            carbs: item.nutrition?.carbs.map { String($0) } ?? "",
            fat: item.nutrition?.fat.map { String($0) } ?? ""
        )
    }

    func makeInventoryItem(householdID: String, userID: String?) -> InventoryItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        let nutrition = NutritionInfo(
            calories: Double(calories),
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat),
            unit: trimmedUnit
        )

        return InventoryItem(
            id: id,
            name: trimmedName,
            barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode,
            category: trimmedCategory.isEmpty ? "Uncategorized" : trimmedCategory,
            quantity: max(0, quantity),
            unit: trimmedUnit.isEmpty ? "pcs" : trimmedUnit,
            expirationDate: expirationDate,
            nutrition: nutrition.isEmpty ? nil : nutrition,
            timestamp: Date(),
            householdID: householdID,
            createdBy: userID,
            updatedBy: userID
        )
    }
}

struct InventoryError: LocalizedError, Identifiable {
    let id = UUID()
    let message: String

    var errorDescription: String? { message }
}

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published var isPresentingEditor = false
    @Published var isSaving = false
    @Published var draft = InventoryDraft()
    @Published var alert: InventoryError?

    private let repository: InventoryRepository
    private var cancellables = Set<AnyCancellable>()
    private var householdID: String?
    private var userID: String?

    init(repository: InventoryRepository = InventoryRepository()) {
        self.repository = repository

        repository.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.items = items
            }
            .store(in: &cancellables)
    }

    func updateSession(householdID: String?, userID: String?) {
        if self.householdID != householdID {
            repository.stopListening()
            if let householdID {
                repository.startListening(for: householdID)
            }
        }

        self.householdID = householdID
        self.userID = userID

        if householdID == nil {
            items = []
        }
    }

    func presentAddItem() {
        draft = InventoryDraft()
        isPresentingEditor = true
    }

    func presentEdit(for item: InventoryItem) {
        draft = InventoryDraft(item: item)
        isPresentingEditor = true
    }

    func dismissEditor() {
        isPresentingEditor = false
    }

    func saveDraft() async {
        guard let householdID else {
            alert = InventoryError(message: "A household has not been selected.")
            return
        }

        isSaving = true
        let item = draft.makeInventoryItem(householdID: householdID, userID: userID)

        do {
            if draft.id == nil {
                try await repository.add(item, to: householdID)
            } else {
                try await repository.update(item, in: householdID)
            }
            isPresentingEditor = false
        } catch {
            alert = InventoryError(message: error.localizedDescription)
        }

        isSaving = false
    }

    func deleteItems(at offsets: IndexSet) async {
        let itemsToDelete = offsets.compactMap { items[safe: $0] }
        await delete(items: itemsToDelete)
    }

    func delete(items: [InventoryItem]) async {
        guard let householdID else { return }

        for item in items {
            do {
                try await repository.delete(item, from: householdID)
            } catch {
                alert = InventoryError(message: error.localizedDescription)
            }
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
