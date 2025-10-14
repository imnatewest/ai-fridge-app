import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

enum FirebaseServiceError: LocalizedError {
    case missingUser
    case missingHousehold
    case missingDocumentID

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "User session is unavailable. Please sign in again."
        case .missingHousehold:
            return "Unable to resolve a household for the current user."
        case .missingDocumentID:
            return "Item is missing a document identifier."
        }
    }
}

final class FirebaseService {
    static let shared = FirebaseService()

    let auth: Auth
    let db: Firestore

    init(auth: Auth = Auth.auth(), db: Firestore = Firestore.firestore()) {
        self.auth = auth
        self.db = db
    }

    func signInAnonymously() async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            auth.signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: FirebaseServiceError.missingUser)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    func householdDocument(for householdID: String) -> DocumentReference {
        db.collection("households").document(householdID)
    }

    func itemsCollection(for householdID: String) -> CollectionReference {
        householdDocument(for: householdID).collection("items")
    }

    func ensureHouseholdDocumentExists(for householdID: String) async throws {
        let document = householdDocument(for: householdID)
        let snapshot = try await document.getDocumentAsync()
        if snapshot.exists { return }

        let household = Household.makeDefault(for: householdID)
        try await document.setDataAsync(from: household)
    }
}
