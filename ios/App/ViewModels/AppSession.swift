import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var householdID: String?
    @Published private(set) var isLoading = false
    @Published var error: LocalizedError?

    private let service: FirebaseService

    init(service: FirebaseService = .shared) {
        self.service = service
        Task {
            await ensureSignedIn()
        }
    }

    func ensureSignedIn() async {
        if let currentUser = service.auth.currentUser {
            await configureSession(with: currentUser)
            return
        }

        do {
            isLoading = true
            let user = try await service.signInAnonymously()
            await configureSession(with: user)
        } catch {
            self.error = error as? LocalizedError
        }

        isLoading = false
    }

    private func configureSession(with user: User) async {
        self.user = user
        householdID = user.uid

        do {
            try await service.ensureHouseholdDocumentExists(for: user.uid)
        } catch {
            self.error = error as? LocalizedError
        }
    }
}
