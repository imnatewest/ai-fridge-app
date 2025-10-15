//
//  NutritionFactsCard.swift
//  AIFridge
//
//  Created by Nathan West on 10/17/25.
//

import SwiftUI

struct NutritionFactsCard: View {
    let nutrition: Item.Nutrition
    let servingDescription: String?

    private var caloriesText: String {
        if let calories = nutrition.calories {
            return calories.formattedNutritionValue(precision: 0)
        }
        if let rawCalories = nutrition.raw?["energy-kcal_serving"] {
            return rawCalories.formattedNutritionValue(precision: 0)
        }
        return "—"
    }

    private var entries: [NutritionFactsEntry] {
        NutritionFactsFormatter.entries(for: nutrition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Facts")
                .font(.system(size: 30, weight: .black, design: .default))
                .foregroundColor(.black)

            if let servingDescription, !servingDescription.isEmpty {
                Text("Serving size \(servingDescription)")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.black)
            }

            NutritionDivider(style: .extraThick)

            Text("Amount per serving")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(.black)

            HStack(alignment: .firstTextBaseline) {
                Text("Calories")
                    .font(.system(size: 28, weight: .heavy, design: .default))
                    .foregroundColor(.black)
                Spacer()
                Text(caloriesText)
                    .font(.system(size: 36, weight: .heavy, design: .default))
                    .foregroundColor(.black)
            }

            NutritionDivider(style: .extraThick)

            HStack {
                Spacer()
                Text("% Daily Value*")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.black)
            }

            NutritionDivider(style: .thin)

            ForEach(entries.indices, id: \.self) { index in
                let entry = entries[index]
                NutritionRow(entry: entry)

                if index < entries.count - 1 {
                    NutritionDivider(style: entry.showsSubDivider ? .thick : .thin)
                }
            }

            NutritionDivider(style: .extraThick)

            Text("*Percent Daily Values are based on a 2,000 calorie diet.")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.black.opacity(0.75))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Supporting Views
private struct NutritionRow: View {
    let entry: NutritionFactsEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.title)
                .font(.system(size: entry.isBold ? 16 : 14, weight: entry.isBold ? .semibold : .regular, design: .default))
                .foregroundColor(.black)
                .padding(.leading, CGFloat(entry.indentLevel) * 14)
            Spacer()
            Text(entry.amountText)
                .font(.system(size: entry.isBold ? 16 : 14, weight: entry.isBold ? .semibold : .regular, design: .default))
                .foregroundColor(.black)
            if let dailyPercent = entry.dailyPercentText {
                Text(dailyPercent)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.black)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .accessibilityLabel(entry.accessibilityLabel)
    }
}

private struct NutritionDivider: View {
    enum Style {
        case extraThick
        case thick
        case thin
    }

    let style: Style

    var body: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .padding(.vertical, padding)
            .accessibilityHidden(true)
    }

    private var height: CGFloat {
        switch style {
        case .extraThick:
            return 8
        case .thick:
            return 4
        case .thin:
            return 1
        }
    }

    private var padding: CGFloat {
        switch style {
        case .extraThick:
            return 4
        case .thick:
            return 3
        case .thin:
            return 1
        }
    }
}

// MARK: - Formatter
private enum NutritionFactsFormatter {
    static func entries(for nutrition: Item.Nutrition) -> [NutritionFactsEntry] {
        guard let raw = nutrition.raw else { return [] }

        return descriptors.compactMap { descriptor in
            guard let value = descriptor.resolveValue(from: raw) else {
                return nil
            }
            let normalized = descriptor.unit.normalizedAmount(value)
            return NutritionFactsEntry(
                id: descriptor.id,
                title: descriptor.title,
                amountText: "\(normalized.formattedNutritionValue())\(descriptor.unit.displaySuffix)",
                dailyPercentText: descriptor.dailyValuePercentageText(for: normalized),
                indentLevel: descriptor.indentLevel,
                isBold: descriptor.isBold,
                showsSubDivider: descriptor.showsSubDivider,
                accessibilityLabel: descriptor.accessibilityLabel(for: normalized)
            )
        }
    }

    private static let descriptors: [NutritionDescriptor] = [
        NutritionDescriptor(
            keys: ["fat_serving", "fat_value_serving"],
            title: "Total Fat",
            unit: .grams,
            dailyValue: 78,
            indentLevel: 0,
            isBold: true,
            showsSubDivider: false
        ),
        NutritionDescriptor(
            keys: ["saturated-fat_serving", "saturated-fat_value_serving"],
            title: "Saturated Fat",
            unit: .grams,
            dailyValue: 20,
            indentLevel: 1
        ),
        NutritionDescriptor(
            keys: ["trans-fat_serving", "trans-fat_value_serving"],
            title: "Trans Fat",
            unit: .grams,
            dailyValue: nil,
            indentLevel: 1,
            showsSubDivider: true
        ),
        NutritionDescriptor(
            keys: ["cholesterol_serving", "cholesterol_value_serving"],
            title: "Cholesterol",
            unit: .milligramsFromGrams,
            dailyValue: 300,
            indentLevel: 0,
            isBold: true,
            showsSubDivider: true
        ),
        NutritionDescriptor(
            keys: ["sodium_serving", "sodium_value_serving"],
            title: "Sodium",
            unit: .milligramsFromGrams,
            dailyValue: 2300,
            indentLevel: 0,
            isBold: true,
            showsSubDivider: true
        ),
        NutritionDescriptor(
            keys: ["carbohydrates_serving", "carbohydrates_value_serving"],
            title: "Total Carbohydrate",
            unit: .grams,
            dailyValue: 275,
            indentLevel: 0,
            isBold: true
        ),
        NutritionDescriptor(
            keys: ["fiber_serving", "fiber_value_serving", "dietary-fiber_serving"],
            title: "Dietary Fiber",
            unit: .grams,
            dailyValue: 28,
            indentLevel: 1
        ),
        NutritionDescriptor(
            keys: ["sugars_serving", "sugars_value_serving"],
            title: "Total Sugars",
            unit: .grams,
            dailyValue: nil,
            indentLevel: 1
        ),
        NutritionDescriptor(
            keys: ["sugars-added_serving", "added-sugars_serving"],
            title: "Includes Added Sugars",
            unit: .grams,
            dailyValue: 50,
            indentLevel: 2,
            showsSubDivider: true
        ),
        NutritionDescriptor(
            keys: ["proteins_serving", "protein_serving"],
            title: "Protein",
            unit: .grams,
            dailyValue: 50,
            indentLevel: 0,
            isBold: true,
            showsSubDivider: true
        ),
        NutritionDescriptor(
            keys: ["vitamin-d_serving"],
            title: "Vitamin D",
            unit: .micrograms,
            dailyValue: 20,
            indentLevel: 0
        ),
        NutritionDescriptor(
            keys: ["calcium_serving"],
            title: "Calcium",
            unit: .milligramsFromGrams,
            dailyValue: 1300,
            indentLevel: 0
        ),
        NutritionDescriptor(
            keys: ["iron_serving"],
            title: "Iron",
            unit: .milligramsFromGrams,
            dailyValue: 18,
            indentLevel: 0
        ),
        NutritionDescriptor(
            keys: ["potassium_serving"],
            title: "Potassium",
            unit: .milligramsFromGrams,
            dailyValue: 4700,
            indentLevel: 0
        )
    ]
}

// MARK: - Models
private struct NutritionFactsEntry: Identifiable {
    let id: String
    let title: String
    let amountText: String
    let dailyPercentText: String?
    let indentLevel: Int
    let isBold: Bool
    let showsSubDivider: Bool
    let accessibilityLabel: String
}

private struct NutritionDescriptor: Identifiable {
    let id = UUID().uuidString
    let keys: [String]
    let title: String
    let unit: NutritionUnit
    let dailyValue: Double?
    let indentLevel: Int
    let isBold: Bool
    let showsSubDivider: Bool

    init(keys: [String],
         title: String,
         unit: NutritionUnit,
         dailyValue: Double?,
         indentLevel: Int,
         isBold: Bool = false,
         showsSubDivider: Bool = false) {
        self.keys = keys
        self.title = title
        self.unit = unit
        self.dailyValue = dailyValue
        self.indentLevel = indentLevel
        self.isBold = isBold
        self.showsSubDivider = showsSubDivider
    }

    func resolveValue(from raw: [String: Double]) -> Double? {
        for key in keys {
            if let value = raw[key] {
                return value
            }
        }
        return nil
    }

    func dailyValuePercentageText(for normalizedAmount: Double) -> String? {
        guard let dailyValue else { return nil }
        guard dailyValue > 0 else { return nil }
        let percentage = (normalizedAmount / dailyValue) * 100
        if percentage.isNaN || percentage.isInfinite {
            return nil
        }
        if percentage > 1 {
            return "\(Int(round(percentage)))%"
        } else if percentage > 0 {
            return "<1%"
        } else {
            return "0%"
        }
    }

    func accessibilityLabel(for normalizedAmount: Double) -> String {
        if let dailyText = dailyValuePercentageText(for: normalizedAmount) {
            return "\(title) \(normalizedAmount.formattedNutritionValue())\(unit.displaySuffix), \(dailyText) of daily value"
        } else {
            return "\(title) \(normalizedAmount.formattedNutritionValue())\(unit.displaySuffix)"
        }
    }
}

private enum NutritionUnit {
    case grams
    case milligrams
    case milligramsFromGrams
    case micrograms

    func normalizedAmount(_ value: Double) -> Double {
        switch self {
        case .grams:
            return value
        case .milligrams:
            return value
        case .milligramsFromGrams:
            return value * 1000
        case .micrograms:
            return value
        }
    }

    var displaySuffix: String {
        switch self {
        case .grams:
            return "g"
        case .milligrams, .milligramsFromGrams:
            return "mg"
        case .micrograms:
            return "mcg"
        }
    }
}

// MARK: - Helpers
private extension Double {
    func formattedNutritionValue(precision: Int = 1) -> String {
        if self == 0 { return "0" }
        if abs(self - rounded()) < 0.0001 {
            return String(Int(rounded()))
        }
        return String(format: "%.\(precision)f", self)
    }
}
