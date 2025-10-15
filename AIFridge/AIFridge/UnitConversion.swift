import Foundation

enum UnitConversion {
    // Very small helper to normalize common small volume/weight units to base units (g and ml)
    // Note: these are heuristic conversions and may not be accurate for all foods.

    static func normalized(_ value: Double, unit: String) -> (value: Double, unit: String) {
        let lower = unit.lowercased()
        switch lower {
        case "g", "gram", "grams":
            return (value, "g")
        case "kg", "kilogram", "kilograms":
            return (value * 1000, "g")
        case "ml", "milliliter", "milliliters":
            return (value, "ml")
        case "l", "liter", "liters":
            return (value * 1000, "ml")
        case "cup", "cups":
            // approximate US cup to ml
            return (value * 240, "ml")
        case "tbsp", "tablespoon", "tablespoons":
            return (value * 15, "ml")
        case "tsp", "teaspoon", "teaspoons":
            return (value * 5, "ml")
        default:
            return (value, unit)
        }
    }
}
