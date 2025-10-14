import SwiftUI

struct ItemDetailView: View {
    let item: InventoryItem
    @State private var showNutrition = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                details
                if let nutrition = item.nutrition {
                    nutritionSection(nutrition)
                }
                activity
            }
            .padding()
        }
        .navigationTitle(item.name)
        .toolbarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.1))
                .frame(height: 160)
                .overlay(
                    Image(systemName: "barcode.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundColor(.accentColor)
                )
            Text(quantityDescription)
                .font(.title3)
                .bold()
            if let status = statusText {
                Label(status.message, systemImage: status.icon)
                    .font(.subheadline)
                    .foregroundColor(status.color)
                    .padding(.vertical, 4)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(title: "Category", value: item.category)
            if let barcode = item.barcode {
                DetailRow(title: "Barcode", value: barcode)
            }
            if let expiration = item.expirationDate {
                DetailRow(title: "Expires", value: expiration.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private func nutritionSection(_ nutrition: NutritionInfo) -> some View {
        DisclosureGroup(isExpanded: $showNutrition) {
            VStack(alignment: .leading, spacing: 8) {
                NutritionRow(label: "Calories", value: nutrition.calories)
                NutritionRow(label: "Protein", value: nutrition.protein, suffix: "g")
                NutritionRow(label: "Carbs", value: nutrition.carbs, suffix: "g")
                NutritionRow(label: "Fat", value: nutrition.fat, suffix: "g")
            }
            .padding(.top, 8)
        } label: {
            Text("Nutrition")
                .font(.headline)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)
            if let createdBy = item.createdBy {
                Text("Added by \(createdBy)")
                    .foregroundColor(.secondary)
            }
            Text("Synced \(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
        }
    }

    private var quantityDescription: String {
        "\(item.quantity, specifier: "%.0f") \(item.unit) available"
    }

    private var statusText: (message: String, icon: String, color: Color)? {
        if item.isExpired {
            return ("Expired", "exclamationmark.triangle.fill", .red)
        }

        if let days = item.expiresInDays() {
            if days <= 0 {
                return ("Expires today", "clock.fill", .orange)
            } else if days <= 3 {
                return ("\(days) days left", "clock", .orange)
            }
        }

        return nil
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NutritionRow: View {
    let label: String
    let value: Double?
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if let value {
                Text("\(value, specifier: "%.0f")\(suffix)")
                    .bold()
            } else {
                Text("—")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ItemDetailView(item: .placeholder)
        }
    }
}
