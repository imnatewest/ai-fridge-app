import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

extension DocumentReference {
    func getDocumentAsync(source: FirestoreSource = .default) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            getDocument(source: source) { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing snapshot"]))
                }
            }
        }
    }

    func setDataAsync(_ documentData: [String: Any], merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            setData(documentData, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func setDataAsync<T: Encodable>(from value: T, merge: Bool = false, encoder: Firestore.Encoder = Firestore.Encoder()) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try setData(from: value, merge: merge, encoder: encoder) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func deleteAsync() async throws {
        try await withCheckedThrowingContinuation { continuation in
            delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension CollectionReference {
    func addDocumentAsync<T: Encodable>(from value: T, encoder: Firestore.Encoder = Firestore.Encoder()) async throws -> DocumentReference {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let reference = try addDocument(from: value, encoder: encoder) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: reference)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
