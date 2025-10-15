//
//  EditItemView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    let db = Firestore.firestore()
    @State var item: Item

    // MARK: - Validation State
    @State private var nameError: String?
    @State private var quantityError: String?
    @State private var expirationError: String?

    var body: some View {
        NavigationStack {
            Form {
                if let barcode = item.barcode, !barcode.isEmpty {
                    Section(header: Text("Product")) {
                        Button {
                            Task { await refetchProduct() }
                        } label: {
                            Label("Refetch product details", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(item.barcode?.isEmpty ?? true)

                        if let brand = item.brand {
                            Text("Brand: \(brand)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Serving:")
                            Spacer()
                            if let sVal = item.servingSizeValue {
                                Text("\(sVal, format: .number)")
                            }
                            if let sUnit = item.servingSizeUnit {
                                Text(sUnit)
                            }
                        }
                    }
                }
                if let barcode = item.barcode, !barcode.isEmpty {
                    Section(header: Text("Barcode")) {
                        Label(barcode, systemImage: "barcode")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section(header: Text("Item Details")) {
                    TextField("Name", text: $item.name)
                        // iOS 17+ onChange (two-parameter or zero-parameter)
                        .onChange(of: item.name) { _, _ in
                            validateName()
                        }

                    if let nameError {
                        Text(nameError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Category", text: Binding(unwrapping: $item.category, replacingNilWith: ""))
                }

                Section(header: Text("Quantity")) {
                    Stepper(value: $item.quantity, in: 0...999, step: 1) {
                        Text("\(Int(item.quantity)) \(item.unit)")
                    }
                    .onChange(of: item.quantity) { _, _ in
                        validateQuantity()
                    }

                    TextField("Unit (e.g., pcs, carton, lbs)", text: $item.unit)
                        .autocapitalization(.none)

                    if let quantityError {
                        Text(quantityError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(header: Text("Expiration")) {
                    DatePicker("Select date",
                               selection: $item.expirationDate,
                               displayedComponents: .date)
                    .onChange(of: item.expirationDate) { _, _ in
                        validateExpiration()
                    }

                    if let expirationError {
                        Text(expirationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit \(item.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            // run initial validation when the view appears
            validateAll()
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
        nameError = item.name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Item name cannot be empty."
            : nil
    }

    private func validateQuantity() {
        quantityError = item.quantity <= 0
            ? "Quantity must be greater than zero."
            : nil
    }

    private func validateExpiration() {
        let now = Calendar.current.startOfDay(for: Date())
        let chosen = Calendar.current.startOfDay(for: item.expirationDate)
        expirationError = chosen < now
            ? "Expiration date cannot be in the past."
            : nil
    }

    // MARK: - Save
    func saveChanges() {
        guard let id = item.id else { return }
        guard isFormValid else {
            print("⚠️ Tried to save invalid form")
            return
        }

        do {
            try db.collection("items").document(id).setData(from: item, merge: true)
            print("✅ Updated item: \(item.name)")
            ExpirationNotificationScheduler.shared.rescheduleNotification(for: item)
            dismiss()
        } catch {
            print("❌ Error updating item: \(error)")
        }
    }

    @MainActor
    private func refetchProduct() async {
        guard let code = item.barcode else { return }
        do {
            if let product = try await OpenFoodFactsService.shared.lookup(barcode: code) {
                let mapped = OpenFoodFactsService.shared.itemFromProduct(product, barcode: code)
                // apply mapped fields to item (preserve user edits)
                item.brand = mapped.brand ?? item.brand
                if let sVal = mapped.servingSizeValue { item.servingSizeValue = sVal }
                if let sUnit = mapped.servingSizeUnit { item.servingSizeUnit = sUnit }
                if let nServing = mapped.nutritionPerServing { item.nutritionPerServing = nServing }
            }
        } catch {
            print("❌ Error refetching product: \(error)")
        }
    }
}

#Preview {
    EditItemView(item: Item(
        name: "",
        category: nil,
        quantity: 0,
        unit: "pcs",
        expirationDate: Date(),
        timestamp: Date(),
        barcode: nil
    ))
}
