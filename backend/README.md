# Backend Service Structure

This directory houses the AI and data orchestration layer referenced in the product vision. The service can be implemented with FastAPI or Node.js; the structure below assumes FastAPI with Python.

- `app/core` – Configuration, settings, and shared dependencies (Firebase, vector search, and OpenAI/Anthropic clients).
- `app/models` – Pydantic models for receipt payloads, inventory items, and recipe responses.
- `app/api` – Route handlers for `/parse-receipt`, `/recipes`, and future endpoints such as waste insights.
- `app/services` – Integrations with OCR providers, Open Food Facts, receipt normalization, and prompt engineering utilities.
- `tests` – Automated tests for API contracts, prompt regressions, and business rules.
