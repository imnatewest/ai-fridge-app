import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

final class InventoryRepository: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []

    private let service: FirebaseService
    private var listener: ListenerRegistration?
    private let decoder = Firestore.Decoder()

    init(service: FirebaseService = .shared) {
        self.service = service
    }

    func startListening(for householdID: String) {
        listener?.remove()
        listener = service
            .itemsCollection(for: householdID)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("Failed to fetch inventory: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.items = []
                    return
                }

                let decoded: [InventoryItem] = documents.compactMap { document in
                    do {
                        return try document.data(as: InventoryItem.self, decoder: self.decoder)
                    } catch {
                        print("Failed to decode item: \(error)")
                        return nil
                    }
                }

                DispatchQueue.main.async {
                    self.items = decoded
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        DispatchQueue.main.async {
            self.items = []
        }
    }

    func add(_ item: InventoryItem, to householdID: String) async throws {
        _ = try await service.itemsCollection(for: householdID).addDocumentAsync(from: item)
    }

    func update(_ item: InventoryItem, in householdID: String) async throws {
        guard let documentID = item.id else { throw FirebaseServiceError.missingDocumentID }
        try await service
            .itemsCollection(for: householdID)
            .document(documentID)
            .setDataAsync(from: item, merge: true)
    }

    func delete(_ item: InventoryItem, from householdID: String) async throws {
        guard let documentID = item.id else { return }
        try await service
            .itemsCollection(for: householdID)
            .document(documentID)
            .deleteAsync()
    }
}
