# UX Wireframes

The following wireframes describe the core flows for the mobile application. Each section includes a high-level storyboard, key interactions, and UI notes to guide implementation and user testing.

## 1. Scanning Flow

```
┌──────────────────────────────┐
│  Scan & Add Item             │
├──────────────────────────────┤
│ [Camera Viewfinder]          │
│  ▢ Barcode framing guide     │
│  ─────────────────────────   │
│  ▢ Flash toggle   ▢ Help     │
│                              │
│  [Manual entry link]         │
└────────────┬─────────────────┘
             ▼
┌──────────────────────────────┐
│  Match Found                 │
├──────────────────────────────┤
│  Item name + thumbnail       │
│  ▢ Quantity stepper          │
│  ▢ Expiration date picker    │
│  ▢ Category chip selector    │
│                              │
│ [Add to inventory] [Edit]    │
└────────────┬─────────────────┘
             ▼
┌──────────────────────────────┐
│  Confirmation Banner         │
├──────────────────────────────┤
│  "Yogurt added to Fridge"    │
│  ▢ View item                 │
│  ▢ Scan another              │
└──────────────────────────────┘
```

**Key interactions**

- Primary entry point: floating action button (FAB) on inventory list.
- Default to live camera with barcode framing guide and haptic feedback when detection occurs.
- Manual entry link opens the inventory editor with barcode prefilled (if captured) but allows typing when scanning fails.
- After a successful scan, the confirmation screen pre-populates metadata fetched from the product catalog. Users can adjust quantity, unit, and expiration date before saving.
- Confirmation banner briefly appears and can be tapped to open the detail view for further edits.

**UI notes**

- Flash toggle and help icon anchored at the top-right to avoid covering the camera feed.
- Action buttons pinned to the bottom for one-handed reachability.
- When no match is found, display a fallback screen with manual entry fields prioritized.

## 2. Inventory List

```
┌──────────────────────────────┐
│  Inventory (12)              │
│  Search ▢ Filter ▢ Sort      │
├──────────────────────────────┤
│ • Overdue                    │
│   - Milk (2 cartons) ⚠︎      │
│   - Spinach (1 bag) ⚠︎       │
│ • Expiring Soon              │
│   - Yogurt (4 cups)          │
│ • In Stock                   │
│   - Eggs (12 pcs)            │
│   - Apples (6 pcs)           │
│                              │
│ [Floating Scan Button]       │
└──────────────────────────────┘
```

**Key interactions**

- Segmented grouping surfaces status buckets (overdue, expiring soon, in stock) based on expiration date and quantity thresholds.
- Swipe left on any row reveals quick actions: decrement quantity, edit, delete.
- Pull-to-refresh triggers a manual sync with Firestore when needed.
- Search uses incremental filtering across name, category, and barcode fields.
- Filter drawer offers category chips, inventory location toggles, and member-specific views.
- FAB anchored to bottom-right opens the scanning flow.

**UI notes**

- Rows include a thumbnail placeholder, name, quantity/unit, and a status badge (color-coded by freshness).
- Section headers are sticky to help orientation in long lists.
- Empty state displays illustrated guidance with a direct call-to-action to scan the first item.

## 3. Item Detail View

```
┌──────────────────────────────┐
│  Yogurt                      │
│  ▢ Back                      │
├──────────────────────────────┤
│  [Hero image / placeholder]  │
│  Quantity: 4 cups            │
│  Expires in 3 days ⚠︎        │
│                              │
│  Notes                       │
│  - Brand, flavor, etc.       │
│                              │
│  Nutrition                   │
│  Calories 120   Protein 5 g  │
│  Carbs 17 g    Fat 3 g       │
│                              │
│  Activity                    │
│  - Added by Alex 2h ago      │
│  - Last edited today         │
│                              │
│ [Edit Item]  [Move / Consume]│
└──────────────────────────────┘
```

**Key interactions**

- Primary CTA is `Edit Item`, presenting the same editor used for creation but seeded with existing values.
- Secondary CTA offers contextual quick actions such as "Mark as consumed" or "Move to Shopping List".
- A collapsible nutrition section surfaces macro nutrients and any additional labels provided by the catalog.
- Activity log shows timestamped events for auditing and transparency within the household.

**UI notes**

- Emphasize freshness by placing expiration status near the top and using color-coded icons.
- Use cards to visually separate sections (details, nutrition, activity).
- Support swipe down to dismiss when presented modally from the inventory list.

## Visual Consistency Checklist

- Rounded 12pt corners for cards and primary buttons.
- Use system font with dynamic type support; adopt `headline` for item names and `subheadline` for metadata.
- Accent color derived from the brand palette; apply consistently to primary actions and status indicators.
- Provide haptic feedback for critical actions (scan success, save, delete).

These wireframes serve as the baseline reference for the design and engineering team. Iterate with usability testing before high-fidelity mocks.
