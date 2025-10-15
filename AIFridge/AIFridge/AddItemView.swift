//
//  AddItemView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    let db = Firestore.firestore()

    // MARK: - Form State
    @State private var name = ""
    @State private var category = ""
    @State private var quantity = 1.0
    @State private var unit = "pcs"
    @State private var expirationDate = Date().addingTimeInterval(60 * 60 * 24 * 7) // +1 week
    @State private var barcode = ""
    @State private var brand = ""
    @State private var servingSizeValue: Double? = nil
    @State private var servingSizeUnit: String? = nil
    @State private var nutritionPerServing: Item.Nutrition? = nil
    @State private var productStatusMessage: String?
    @State private var isFetchingProduct = false
    @State private var showScanner = false

    // MARK: - Validation State
    @State private var nameError: String?
    @State private var quantityError: String?
    @State private var expirationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Capture")) {
                    Button {
                        showScanner = true
                    } label: {
                        ScanBarcodeButtonLabel(isLoading: isFetchingProduct)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingProduct)

                    if !barcode.isEmpty {
                        Label(barcode, systemImage: "barcode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if isFetchingProduct {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Fetching product details…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let productStatusMessage {
                        Text(productStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Product")) {
                    TextField("Brand", text: $brand)
                        .autocapitalization(.words)

                    HStack {
                        TextField("Serving size value", value: Binding(unwrapping: $servingSizeValue, replacingNilWith: 0.0), format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Unit", text: Binding(unwrapping: $servingSizeUnit, replacingNilWith: ""))
                            .frame(width: 80)
                            .autocapitalization(.none)
                    }

                    if let n = nutritionPerServing {
                        NutritionFactsCard(
                            nutrition: n,
                            servingDescription: servingSizeDescription
                        )
                        .padding(.top, DesignSpacing.sm)
                    }
                }

                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, _ in validateName() }

                    if let nameError {
                        Text(nameError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Category", text: $category)
                        .autocapitalization(.none)
                }

                Section(header: Text("Quantity")) {
                    Stepper(value: $quantity, in: 0...999, step: 1) {
                        Text("\(Int(quantity)) \(unit)")
                    }
                    .onChange(of: quantity) { _, _ in validateQuantity() }

                    TextField("Unit (e.g., pcs, carton, lbs)", text: $unit)
                        .autocapitalization(.none)

                    if let quantityError {
                        Text(quantityError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(header: Text("Expiration")) {
                    DatePicker("Select date",
                               selection: $expirationDate,
                               displayedComponents: .date)
                    .onChange(of: expirationDate) { _, _ in validateExpiration() }

                    if let expirationError {
                        Text(expirationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear { validateAll() }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { code in
                handleScannedBarcode(code)
            }
        }
    }

    // MARK: - Helpers
    private var servingSizeDescription: String? {
        guard let value = servingSizeValue else { return nil }
        let formattedValue = formattedServingSize(value)

        guard let unit = servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty else {
            return formattedValue
        }
        return "\(formattedValue) \(unit)"
    }

    // MARK: - Validation Logic
    private var isFormValid: Bool {
        nameError == nil && quantityError == nil && expirationError == nil
    }

    private func validateAll() {
        validateName()
        validateQuantity()
        validateExpiration()
    }

    private func validateName() {
        nameError = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Item name cannot be empty."
            : nil
    }

    private func validateQuantity() {
        quantityError = quantity <= 0
            ? "Quantity must be greater than zero."
            : nil
    }

    private func validateExpiration() {
        let now = Calendar.current.startOfDay(for: Date())
        let chosen = Calendar.current.startOfDay(for: expirationDate)
        expirationError = chosen < now
            ? "Expiration date cannot be in the past."
            : nil
    }

    // MARK: - Save Item
    func saveItem() {
        guard isFormValid else {
            print("⚠️ Tried to save invalid form")
            return
        }

        var newItem = Item(
            id: nil,
            name: name,
            category: category.isEmpty ? nil : category,
            quantity: quantity,
            unit: unit,
            expirationDate: expirationDate,
            timestamp: Date(),
            barcode: barcode.isEmpty ? nil : barcode,
            brand: brand.isEmpty ? nil : brand,
            servingSizeValue: servingSizeValue,
            servingSizeUnit: servingSizeUnit,
            nutritionPer100g: nil,
            nutritionPerServing: nutritionPerServing
        )

        do {
            let reference = try db.collection("items").addDocument(from: newItem)
            newItem.id = reference.documentID
            ExpirationNotificationScheduler.shared.scheduleNotification(for: newItem)
            print("✅ Added new item: \(newItem.name)")
            dismiss()
        } catch {
            print("❌ Error saving item: \(error)")
        }
    }

    private func handleScannedBarcode(_ code: String) {
        let sanitized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return }

        guard !isFetchingProduct else { return }

        barcode = sanitized
        productStatusMessage = "Looking up product…"
        isFetchingProduct = true

        Task {
            do {
                if let product = try await OpenFoodFactsService.shared.lookup(barcode: sanitized) {
                    await MainActor.run {
                        applyProduct(product)
                        productStatusMessage = "Loaded details from \(product.primaryBrand ?? "Open Food Facts")."
                    }
                } else {
                    await MainActor.run {
                        productStatusMessage = "No product found. Enter details manually."
                    }
                }
            } catch {
                await MainActor.run {
                    productStatusMessage = "Lookup failed: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                isFetchingProduct = false
            }
        }
    }

    @MainActor
    private func applyProduct(_ product: OpenFoodFactsProduct) {
        // Use the service mapper to create a partial Item and apply fields
        let mapped = OpenFoodFactsService.shared.itemFromProduct(product, barcode: barcode.isEmpty ? nil : barcode)

        name = mapped.name
        validateName()

        if let c = mapped.category { category = c }
        if let b = mapped.brand { brand = b }
        quantity = max(mapped.quantity, 1)
        unit = mapped.unit
        validateQuantity()

        if let sVal = mapped.servingSizeValue { servingSizeValue = sVal }
        if let sUnit = mapped.servingSizeUnit { servingSizeUnit = sUnit }
        nutritionPerServing = mapped.nutritionPerServing
    }

    private func formattedServingSize(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.001 {
            return String(Int(rounded))
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    AddItemView()
}

private struct ScanBarcodeButtonLabel: View {
    let isLoading: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.45, blue: 0.94),
                Color(red: 0.07, green: 0.32, blue: 0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Scan Barcode")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text("Autofill item details instantly")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                    .tint(.white)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
        .opacity(isEnabled ? 1 : 0.6)
    }
}
