//
//  InventoryListView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct InventoryListView: View {
    @State private var items: [Item] = []
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    @State private var sortOption: SortOption = .expirationSoon
    @State private var selectedCategory: String = "All"

    let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            VStack {
                // 🔹 Filter & sort controls
                HStack {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag("All")
                        ForEach(uniqueCategories, id: \.self) { category in
                            Text(category)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                List {
                    ForEach(filteredAndSortedItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("\(Int(item.quantity)) \(item.unit)")
                                    .foregroundStyle(.secondary)
                                Text("Expires: \(item.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deleteItem)
                }
            }
            .navigationTitle("My Fridge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .sheet(isPresented: $showingAddItem) {
                        AddItemView()
                    }
                }
            }
            .onAppear {
                listenToInventory()
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item)
            }
        }
    }

    // MARK: - Computed filtered/sorted items
    private var filteredAndSortedItems: [Item] {
        var filtered = items

        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        switch sortOption {
        case .expirationSoon:
            return filtered.sorted { $0.expirationDate < $1.expirationDate }
        case .quantityHigh:
            return filtered.sorted { $0.quantity > $1.quantity }
        case .recentlyAdded:
            return filtered.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private var uniqueCategories: [String] {
        let categories = items.compactMap { $0.category }
        return Array(Set(categories)).sorted()
    }

    // MARK: - Firestore listener
    func listenToInventory() {
        db.collection("items")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading items: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found in Firestore.")
                    return
                }

                items = documents.compactMap { doc in
                    try? doc.data(as: Item.self)
                }

                print("✅ Loaded \(items.count) items")
            }
    }

    // MARK: - Safe delete
    func deleteItem(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        withAnimation(.none) {
            for item in itemsToDelete {
                if let id = item.id {
                    db.collection("items").document(id).delete { error in
                        if let error = error {
                            print("❌ Error deleting item: \(error)")
                        } else {
                            print("🗑️ Deleted item: \(item.name)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sort options
enum SortOption: String, CaseIterable {
    case expirationSoon = "Expiring Soon"
    case quantityHigh = "Quantity"
    case recentlyAdded = "Recently Added"
}

#Preview {
    InventoryListView()
}
