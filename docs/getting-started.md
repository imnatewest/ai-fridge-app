# Project Kickoff Guide

This guide outlines the recommended first steps to bring the AI Fridge Companion from concept to an executable MVP. It assumes a small cross-functional team with design, iOS, backend, and AI expertise.

## 1. Align on scope and success metrics
- Review the product vision, personas, and MVP roadmap in the root `README.md`.
- Define the success metrics for the first TestFlight beta (e.g., inventory accuracy, retention, NPS).
- Identify open questions or constraints (budget for AI calls, supported regions, dietary focus) and capture them in an issue tracker.

## 2. Solidify UX with lightweight artifacts
- Produce wireframes for the onboarding, inventory list, item detail, and recipe surfaces.
- Validate flows with 3–4 prospective users to confirm the jobs-to-be-done and terminology.
- Convert the agreed flows into a shared design system (colors, type, components) before coding.

## 3. Stand up the mobile foundation (Week 1–2)
- Initialize the SwiftUI project using Xcode 15, enabling SwiftData or CoreData as needed for offline caching.
- Integrate Firebase Authentication and Firestore; stub household data with sample documents.
- Implement the base inventory list view, including add/edit/delete interactions backed by Firestore.
- Configure SwiftLint and unit test targets to ensure continuous code quality.

## 4. Establish backend & AI services (Week 2–5)
- Spin up a FastAPI service with routes for `/parse-receipt` and `/recipes`.
- Implement receipt parsing pipeline:
  - Upload endpoint storing source assets in object storage (Firebase Storage or S3).
  - OCR layer (VisionKit server-side, Google Vision, or AWS Textract) to extract raw text.
  - LLM post-processing (OpenAI GPT-4o, Claude 3.5) to normalize into the pantry schema.
- Add recipe generation orchestrator that reads household inventory and calls an LLM for suggestions.
- Set up local development tooling (Docker, Poetry/uv or npm) and CI checks (lint, type-checks, tests).

## 5. Integrate barcode scanning (Week 3)
- Use AVFoundation/VisionKit for scanning and debounce results to limit duplicate network calls.
- Query Open Food Facts to pre-fill product metadata; persist to Firestore on confirmation.
- Build manual entry fallback for unrecognized barcodes with form validation.

## 6. Layer in expiration tracking & notifications (Week 4)
- Extend the data model with expiration estimation logic and user-configurable reminders.
- Implement background refresh to surface upcoming expirations via push notifications.
- Provide household sharing (Firestore security rules + listener updates) to keep members in sync.

## 7. Deliver meal intelligence (Week 5)
- Connect the iOS client to the `/recipes` endpoint with Combine publishers.
- Present recipe cards highlighting missing ingredients and offering "add to shopping list" actions.
- Capture user feedback ("hide", "cook later") to improve future recommendations.

## 8. Add shopping list and nutrition insights (Week 6)
- Generate shopping lists automatically based on recipe gaps and low-inventory thresholds.
- Surface nutrition summaries per item and per meal leveraging Open Food Facts data.
- Introduce simple analytics events (Mixpanel/Amplitude) for feature usage.

## 9. Polish, test, and prepare for beta (Week 7–8)
- Run end-to-end tests, address crash reporting, and optimize performance for low-end devices.
- Localize key flows (EN first, then consider ES/FR) and add accessibility labels.
- Conduct hallway usability tests and iterate on the most critical feedback.
- Create the TestFlight build, document release notes, and schedule feedback interviews.

## 10. Operational readiness
- Document deployment workflows for backend services (staging vs. production environments).
- Define an incident response playbook, escalation policy, and on-call rotation.
- Instrument cost monitoring for AI calls and storage usage.
- Plan for data export/delete workflows to satisfy privacy requirements.

---
Use this guide as a living document—update it as assumptions change and the team discovers new opportunities.
