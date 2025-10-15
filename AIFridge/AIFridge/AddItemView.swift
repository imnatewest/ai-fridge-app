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
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
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
            name: name,
            category: category.isEmpty ? nil : category,
            quantity: quantity,
            unit: unit,
            expirationDate: expirationDate,
            timestamp: Date(),
            barcode: barcode.isEmpty ? nil : barcode
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
        if let nameFromProduct = product.displayName {
            name = nameFromProduct
            validateName()
        }

        if let categoryFromProduct = product.primaryCategory {
            category = categoryFromProduct
        }

        if let quantityTuple = product.parsedQuantity {
            quantity = max(quantityTuple.amount, 1)
            unit = quantityTuple.unit
            validateQuantity()
        }
    }
}

#Preview {
    AddItemView()
}
