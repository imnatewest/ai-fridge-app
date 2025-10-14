# iOS App Structure

This directory contains the SwiftUI + Combine client for the AI Fridge App. The structure mirrors the MVP roadmap described in the root README.

- `App/Models` – Value types for `Item`, `Household`, and related entities synced with Firestore.
- `App/ViewModels` – Observable objects that coordinate inventory capture, barcode scanning, expiration reminders, and recipe fetching.
- `App/Views` – SwiftUI views for the inventory list, item detail, meal recommendations, and shopping list screens.
- `App/Services` – Networking and integration code for Firebase Auth, Firestore, barcode lookups, and the AI backend.
- `App/Resources` – Assets such as `GoogleService-Info.plist`, localization files, and shared prompts.
- `Tests/Unit` – Unit tests for models, services, and business logic.
- `Tests/UI` – UI and snapshot tests for the primary user flows.
