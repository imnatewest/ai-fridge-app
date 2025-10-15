# ai-fridge-app

A digital fridge companion that scans grocery barcodes, maintains an accurate inventory, and turns whatever is on hand into meal inspiration.

## Product vision

Reduce food waste and weeknight stress by giving households a single place to understand what food they already own, when it will expire, and how to transform it into meals they will love.

## Why now

* **Manual tracking fails** – keeping a spreadsheet or whiteboard up to date is tedious. Automating capture with lightning-fast barcode scans solves the hardest part of the workflow.
* **AI is ready** – modern multimodal models can understand ingredient context, recognize products from partial barcode matches, and reason about substitutions, giving the app superpowers that felt impossible a few years ago.
* **Market tailwinds** – food prices keep rising, consumers want to waste less, and smart kitchen devices are becoming mainstream.

## Target users & jobs to be done

| Persona | Core jobs | Pain points today |
| --- | --- | --- |
| Busy family planner | Keep the household stocked, plan meals the kids will eat | Re-buying items already at home, forgetting expiration dates |
| Health-focused professional | Track macros, avoid impulse takeout | No visibility into what ingredients are left after a long week |
| Sustainability advocate | Minimize food waste and packaging | Hard to measure what gets tossed and why |

## Core feature set

1. **Inventory capture**
   * Scan product barcodes with VisionKit/AVFoundation for instant recognition.
   * Support manual entry for leftovers, farmers-market finds, or pantry staples.
   * Offer smart search and suggestions while typing to accelerate manual additions.
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
* **AI layer:** Python (FastAPI) or Node.js service enriching scanned products, generating meal recommendations, and answering pantry questions with OpenAI GPT-4o or Anthropic Claude 3.5.
* **Data storage:** Pantry taxonomy stored centrally for normalization, barcode metadata cache, plus vector search (Pinecone/Weaviate) for fuzzy item matching.
* **Analytics:** Mixpanel or Amplitude for user behavior insights, plus Firebase Crashlytics for stability.

## AI & data considerations

* **Prompt engineering:** maintain reusable system prompts for ingredient normalization, barcode disambiguation, and recipe generation.
* **Feedback loop:** capture user corrections to improve future barcode matches and ingredient normalization (few-shot tuning, embeddings, or fine-tuning when viable).
* **Privacy:** keep barcode scans and household data encrypted at rest and in transit, allow easy data export/delete, and avoid training on private content without explicit consent.
* **Cost control:** batch model calls, cache normalized products, and fall back to on-device ML for simple cases.

## MVP roadmap (barcode-first, approx. 8–10 weeks)

### Week 1–2 – Foundations & Data Model
- Finalize UX wireframes for scanning flow, inventory list, and item detail view.  
- Define data models:  
  `Item: name, barcode, category, quantity, unit, expiration_date, nutrition, timestamp`  
  `User / Household: members[], settings, preferences`  
- Set up SwiftUI project with Firebase Auth + Firestore sync.  
- Implement basic inventory list UI with add/edit/delete.

### Week 3 – Barcode Scanning & Product Lookup
- Integrate AVFoundation or VisionKit for real-time barcode scanning.  
- On successful scan, fetch metadata from the Open Food Facts API.  
- Populate fields (`name`, `brand`, `category`, `nutrition_grade`) and store in Firestore.  
- Add manual entry fallback for unknown barcodes.

### Week 4 – Inventory Management & Expiration Logic
- Editable quantities and local expiration reminders.  
- Household sharing and offline persistence.

### Week 5 – Meal Recommendations (AI Layer)
- Backend `/recipes` endpoint generates meal ideas from current inventory using GPT-4o / Claude.  
- Display recipe cards highlighting missing ingredients.  

### Week 6 – Shopping List & Nutrition
- Auto-generated shopping list for missing ingredients.  
- Nutrition summaries via Open Food Facts data.  

### Week 7 – Analytics & Polish
- Add Mixpanel / Firebase Analytics, refine UI, handle API errors.  
- Run small hallway usability tests.  

### Week 8 – TestFlight Build & Feedback
- Ship TestFlight beta, gather feedback, and choose next phase:
  • Add smart grocery list forecasting  or  • Add fridge snapshot AI vision.


## Getting started locally

1. Create a new SwiftUI iOS project (`xcode-select --install` if needed).
2. Add package dependencies for Firebase (Authentication, Firestore) and the chosen networking layer (e.g., Alamofire).
3. Provision Firebase project, download `GoogleService-Info.plist`, and enable anonymous + email auth.
4. Stand up a lightweight backend (FastAPI/Node) with endpoints for `/lookup-barcode` and `/recipes`.
5. Configure environment secrets (API keys, model endpoints) using Xcode schemes or a `.env` loader.
6. Write unit tests for data models and snapshot tests for core SwiftUI views.
7. Wire up CI to run tests and SwiftLint on each pull request.

## Helpful resources

* [Apple VisionKit & AVFoundation](https://developer.apple.com/documentation/visionkit) – barcode and camera capture frameworks on iOS.
* [Firebase Firestore](https://firebase.google.com/docs/firestore) – realtime multi-user sync.
* [OpenAI API](https://platform.openai.com/docs) & [Anthropic Claude](https://docs.anthropic.com/) – multimodal parsing and recipe ideation.
* [Open Food Facts API](https://world.openfoodfacts.org/data) – product metadata and nutrition data.
* [Spoonacular API](https://spoonacular.com/food-api) – broad recipe catalog with dietary filters.

---

Have ideas or feedback? Open an issue or submit a PR! 🚀

## Feature progress

**Overall progress:** 8 / 12 features complete (~67%).

### Completed

- [x] Multi-tab SwiftUI shell that links inventory, recipe discovery, shopping list, insights, and settings destinations for the app experience.
- [x] Firestore-backed inventory dashboard with grid/list modes, filtering controls, hero banner, and automatic ingredient thumbnail fetching via Pexels.
- [x] Add/Edit item flows featuring validation, barcode scanning through VisionKit, Open Food Facts enrichment, and Firestore persistence plus notification scheduling.
- [x] Expiration reminder engine that registers background refresh tasks and syncs pending notifications based on near-term expiry windows.
- [x] Recipe exploration surface with AI suggestion placeholder, tappable recommendation cards, detailed sheets, and Pexels-powered imagery loading.
- [x] Shopping list prototype that groups items by category and supports quick purchased toggles ahead of Firestore sync.
- [x] Insights dashboard combining KPI stat cards with a Charts-based waste breakdown visualization.
- [x] Settings surface with toggles for notifications and AI features, plus privacy actions placeholders.

### Upcoming

- [ ] AI-powered recipe generation service that surfaces tailored meal cards directly from the backend intelligence layer.
- [ ] Automated grocery list sync that forecasts replenishment needs and pushes lists to preferred retailers.
- [ ] Fridge snapshot mode that reconciles inventory through quick shelf photos or short videos.
- [ ] Wearable and voice assistant integrations for hands-free logging and status checks.
