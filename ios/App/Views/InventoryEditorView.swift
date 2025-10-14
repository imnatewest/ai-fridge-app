import SwiftUI

struct InventoryEditorView: View {
    @Binding var draft: InventoryDraft
    let isSaving: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case quantity
        case unit
        case barcode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Item name", text: $draft.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                    TextField("Category", text: $draft.category)
                    TextField("Barcode", text: $draft.barcode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .barcode)
                }

                Section("Quantity") {
                    Stepper(value: $draft.quantity, in: 0...999, step: 1) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(draft.quantity, specifier: "%.0f")")
                                .foregroundColor(.secondary)
                        }
                    }
                    TextField("Unit", text: $draft.unit)
                        .focused($focusedField, equals: .unit)
                }

                Section("Expiration") {
                    DatePicker(
                        "Expiration Date",
                        selection: Binding(
                            get: { draft.expirationDate ?? Date() },
                            set: { draft.expirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .disabled(draft.expirationDate == nil)
                    Toggle("No expiration", isOn: Binding(
                        get: { draft.expirationDate == nil },
                        set: { hasNoExpiration in
                            if hasNoExpiration {
                                draft.expirationDate = nil
                            } else {
                                draft.expirationDate = draft.expirationDate ?? Date()
                            }
                        }
                    ))
                }

                Section("Nutrition (per unit)") {
                    nutritionField(title: "Calories", value: $draft.calories)
                    nutritionField(title: "Protein (g)", value: $draft.protein)
                    nutritionField(title: "Carbs (g)", value: $draft.carbs)
                    nutritionField(title: "Fat (g)", value: $draft.fat)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .navigationTitle(draft.id == nil ? "Add Item" : "Edit Item")
            .onSubmit(focusNextField)
            .onAppear {
                if draft.name.isEmpty {
                    focusedField = .name
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func focusNextField() {
        switch focusedField {
        case .name:
            focusedField = .quantity
        case .quantity:
            focusedField = .unit
        case .unit:
            focusedField = .barcode
        default:
            focusedField = nil
        }
    }

    private func nutritionField(title: String, value: Binding<String>) -> some View {
        TextField(title, text: value)
            .keyboardType(.decimalPad)
    }
}

struct InventoryEditorView_Previews: PreviewProvider {
    static var previews: some View {
        InventoryEditorView(
            draft: .constant(InventoryDraft()),
            isSaving: false,
            onSave: {},
            onCancel: {}
        )
    }
}
