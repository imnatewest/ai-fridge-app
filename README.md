# ai-fridge-app

A digital fridge companion that captures grocery receipts, maintains an accurate inventory, and turns whatever is on hand into meal inspiration.

## Product vision

Reduce food waste and weeknight stress by giving households a single place to understand what food they already own, when it will expire, and how to transform it into meals they will love.

## Why now

* **Manual tracking fails** – keeping a spreadsheet or whiteboard up to date is tedious. Automating the capture from receipts solves the hardest part of the workflow.
* **AI is ready** – modern multimodal models can parse receipts, recognize handwriting, and reason about substitutions, giving the app superpowers that felt impossible a few years ago.
* **Market tailwinds** – food prices keep rising, consumers want to waste less, and smart kitchen devices are becoming mainstream.

## Target users & jobs to be done

| Persona | Core jobs | Pain points today |
| --- | --- | --- |
| Busy family planner | Keep the household stocked, plan meals the kids will eat | Re-buying items already at home, forgetting expiration dates |
| Health-focused professional | Track macros, avoid impulse takeout | No visibility into what ingredients are left after a long week |
| Sustainability advocate | Minimize food waste and packaging | Hard to measure what gets tossed and why |

## Core feature set

1. **Inventory capture**
   * Scan photos or PDFs of grocery receipts with OCR + LLM cleanup.
   * Support manual entry for leftovers, farmers-market finds, or pantry staples.
   * Optional barcode lookup for faster manual additions.
2. **Smart inventory management**
   * Track quantities with partial usage (e.g., half a bell pepper left).
   * Estimate expiration dates and send reminders when items get close.
   * Share a household profile so roommates or partners stay in sync.
3. **Meal intelligence**
   * Recommend recipes based on what is already on hand and personal preferences.
   * Offer substitution ideas that respect dietary restrictions.
   * Generate one-tap shopping lists for missing ingredients.

## Differentiators to explore next

* **Fridge snapshot mode** – use a quick photo or short video of shelves to reconcile inventory visually.
* **Wearable & voice integration** – log items hands-free ("Hey Siri, add oat milk") or ask "What can I cook tonight?".
* **Waste insights** – track which products expire most often, quantify dollars wasted, and suggest behavior changes.
* **Nutrition coaching** – sync with HealthKit to provide macro-aligned suggestions and nudge healthier choices.

## Technical foundation

* **Mobile:** SwiftUI + Combine for a modern iOS-first experience, with modular architecture to scale to iPad and watchOS later.
* **Cloud backend:** Firebase Authentication + Firestore (or Supabase) for real-time syncing between household members.
* **AI layer:** Python (FastAPI) or Node.js service orchestrating receipt OCR (e.g., AWS Textract, Google Vision, or Apple VisionKit) with LLM post-processing (OpenAI GPT-4o, Anthropic Claude 3.5).
* **Data storage:** Pantry taxonomy stored centrally for normalization, plus vector search (Pinecone/Weaviate) for fuzzy item matching.
* **Analytics:** Mixpanel or Amplitude for user behavior insights, plus Firebase Crashlytics for stability.

## AI & data considerations

* **Prompt engineering:** maintain reusable system prompts for receipt parsing, ingredient normalization, and recipe generation.
* **Feedback loop:** capture user corrections to improve future parsing (few-shot tuning, embeddings, or fine-tuning when viable).
* **Privacy:** keep receipts and household data encrypted at rest and in transit, allow easy data export/delete, and avoid training on private content without explicit consent.
* **Cost control:** batch model calls, cache normalized products, and fall back to on-device ML for simple cases.

## MVP roadmap (approx. 8–10 weeks)

1. **Week 1–2 – Foundations**
   * Finalize UX wireframes and data models.
   * Set up repo structure, SwiftUI scaffolding, and CI with Xcode Cloud or GitHub Actions.
2. **Week 3–4 – Receipt ingestion**
   * Integrate document scanner (VisionKit) and send images to backend.
   * Build parsing pipeline with OCR + LLM to return structured line items.
   * Expose manual add/edit flows for corrections.
3. **Week 5–6 – Inventory & sync**
   * Implement Firestore data model, offline persistence, and household sharing.
   * Add expiration estimation heuristics and reminders via push notifications.
4. **Week 7 – Meal recommendations**
   * Connect to recipe APIs or build prompt templates to generate meal ideas.
   * Let users favorite recipes and create auto-generated shopping lists.
5. **Week 8 – Polish & analytics**
   * Instrument analytics, tighten error handling, and prepare TestFlight build.
   * Conduct hallway tests to validate comprehension and delight.

## Getting started locally

1. Create a new SwiftUI iOS project (`xcode-select --install` if needed).
2. Add package dependencies for Firebase (Authentication, Firestore) and the chosen networking layer (e.g., Alamofire).
3. Provision Firebase project, download `GoogleService-Info.plist`, and enable anonymous + email auth.
4. Stand up a lightweight backend (FastAPI/Node) with endpoints for `/parse-receipt` and `/recipes`.
5. Configure environment secrets (API keys, model endpoints) using Xcode schemes or a `.env` loader.
6. Write unit tests for data models and snapshot tests for core SwiftUI views.
7. Wire up CI to run tests and SwiftLint on each pull request.

## Helpful resources

* [Apple VisionKit](https://developer.apple.com/documentation/visionkit) – best-in-class document scanning on iOS.
* [Firebase Firestore](https://firebase.google.com/docs/firestore) – realtime multi-user sync.
* [OpenAI API](https://platform.openai.com/docs) & [Anthropic Claude](https://docs.anthropic.com/) – multimodal parsing and recipe ideation.
* [Open Food Facts API](https://world.openfoodfacts.org/data) – product metadata and nutrition data.
* [Spoonacular API](https://spoonacular.com/food-api) – broad recipe catalog with dietary filters.

---

Have ideas or feedback? Open an issue or submit a PR! 🚀
