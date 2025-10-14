# Item and Household Data Models

The following schemas serve as the canonical source of truth for client and backend implementations. Fields marked optional may be omitted when data is not available. All timestamps use UTC and ISO 8601 formatting when serialized.

## Item

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | no | Firestore document ID generated on create. |
| `name` | string | yes | Human-readable item name. |
| `barcode` | string | no | UPC/EAN/QR barcode captured from scanning. |
| `category` | string | yes | Category slug (e.g., `dairy`, `produce`). |
| `quantity` | number | yes | Numeric quantity for the item. |
| `unit` | string | yes | Unit label (`pcs`, `lbs`, `g`, `ml`, etc.). |
| `expiration_date` | timestamp | no | Expiration or best-by date. |
| `nutrition` | object | no | Optional macro data. |
| `nutrition.calories` | number | no | Calories per unit. |
| `nutrition.protein` | number | no | Protein grams per unit. |
| `nutrition.carbs` | number | no | Carbohydrate grams per unit. |
| `nutrition.fat` | number | no | Fat grams per unit. |
| `nutrition.unit` | string | no | Serving unit for the nutrition values. |
| `timestamp` | timestamp | yes | Creation or last-sync timestamp. |
| `household_id` | string | yes | Foreign key referencing the owning household. |
| `created_by` | string | no | UID of the member who added the item. |
| `updated_by` | string | no | UID of the member who last edited the item. |

### Validation rules

- `quantity` must be greater than or equal to `0`.
- When `expiration_date` is provided, clients should validate that it is not earlier than `timestamp` minus one year to avoid obvious data entry errors.
- Nutrition fields should be normalized per serving; aggregated values (e.g., per package) should be noted via metadata if required.

## User / Household

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Household identifier; also used as Firestore document ID. |
| `members` | array<string> | yes | Firebase Auth UIDs belonging to the household. |
| `settings` | object | yes | System-level configuration. |
| `settings.default_unit` | string | yes | Default unit applied during manual entry (e.g., `pcs`). |
| `settings.notifications_enabled` | boolean | yes | Toggle for push notifications. |
| `settings.low_stock_threshold` | number | yes | Default percentage threshold (0–1) for low-stock alerts. |
| `preferences` | object | yes | Personalization values shared by the household. |
| `preferences.default_sort` | string | yes | Enum: `expiration_date`, `name`, `category`. |
| `preferences.expiration_warning_days` | number | yes | Days before expiration to surface warnings. |
| `preferences.favorite_categories` | array<string> | no | Frequently used categories for quick access. |
| `created_at` | timestamp | yes | Household creation date. |
| `updated_at` | timestamp | yes | Last mutation timestamp. |

### Behaviour notes

- A single Firebase user may belong to multiple households in the future; for now the mobile client pairs the authenticated user with a single household whose ID matches the user UID.
- Clients should read household settings to determine default sort order, filter thresholds, and notification preferences.
- Membership changes trigger re-synchronization of inventory lists to ensure new members receive up-to-date data.

## Firestore Structure (Draft)

```
households/{householdId}
  ├─ members: []
  ├─ settings: {}
  ├─ preferences: {}
  └─ items/{itemId}
       ├─ name
       ├─ barcode
       ├─ ...
```

This structure keeps inventory items scoped to a household document and allows for security rules that restrict access based on membership.
