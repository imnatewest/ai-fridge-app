# iOS App Structure

This directory contains the SwiftUI + Combine client for the AI Fridge App. The structure mirrors the MVP roadmap described in the root README.

## Project Layout

- `App/FridgeTrackerApp.swift` – SwiftUI entry point that configures Firebase and injects the shared `AppSession`.
- `App/Models` – Value types for `InventoryItem`, `Household`, and supporting nutrition metadata.
- `App/ViewModels` – Observable objects that coordinate Firebase Auth, Firestore synchronization, and view state.
- `App/Views` – SwiftUI screens for the inventory list, item editor, and detail experience.
- `App/Services` – Firebase facades (Auth + Firestore) and repository helpers.
- `App/Resources` – Reserved for assets such as `GoogleService-Info.plist`, localization files, and shared prompts.
- `Tests/Unit` – Unit tests for models, services, and business logic.
- `Tests/UI` – UI and snapshot tests for the primary user flows.

## Getting Started

1. Install the latest Xcode and ensure the Swift toolchain targets iOS 16 or newer.
2. Add Firebase packages via Swift Package Manager (FirebaseAuth, FirebaseFirestore, FirebaseFirestoreSwift).
3. Download your Firebase project's `GoogleService-Info.plist` and place it in `App/Resources`.
4. Open the project in Xcode, update the bundle identifier to match your Firebase app, and enable push notifications if required.
5. Run the `FridgeTrackerApp` target on a simulator or device.

The default configuration signs users in anonymously and creates a household document keyed by the authenticated user's UID.
