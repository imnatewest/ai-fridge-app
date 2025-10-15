//
//  ShoppingListView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import Combine

struct ShoppingItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    var isPurchased: Bool
}

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = ShoppingItem.samples

    var groupedItems: [String: [ShoppingItem]] {
        Dictionary(grouping: items) { $0.category }
    }

    func toggle(_ item: ShoppingItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isPurchased.toggle()
    }

    func syncWithFridge() {
        // TODO: Implement Firestore sync.
    }
}

struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            header

            List {
                ForEach(viewModel.groupedItems.keys.sorted(), id: \.self) { category in
                    Section(category) {
                        ForEach(viewModel.groupedItems[category] ?? []) { item in
                            HStack {
                                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isPurchased ? DesignPalette.accentMint : DesignPalette.secondaryText)
                                Text(item.name)
                                    .strikethrough(item.isPurchased)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut) { viewModel.toggle(item) }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.name), \(item.isPurchased ? "purchased" : "not yet purchased")")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            Button {
                viewModel.syncWithFridge()
            } label: {
                Label("Sync with Fridge", systemImage: "arrow.triangle.2.circlepath")
                    .font(DesignTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, DesignSpacing.md)
            .padding(.bottom, DesignSpacing.lg)
        }
        .background(DesignPalette.background.ignoresSafeArea())
        .navigationTitle("Shopping List")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text("Plan ahead")
                .font(DesignTypography.title)
            Text("Keep ingredients aligned with recipes and household needs.")
                .font(DesignTypography.body)
                .foregroundStyle(DesignPalette.secondaryText)
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.top, DesignSpacing.md)
    }
}

private extension ShoppingItem {
    static let samples: [ShoppingItem] = [
        ShoppingItem(id: UUID(), name: "Parmesan Cheese", category: "Dairy", isPurchased: false),
        ShoppingItem(id: UUID(), name: "Baby Spinach", category: "Produce", isPurchased: false),
        ShoppingItem(id: UUID(), name: "Spaghetti", category: "Pantry", isPurchased: true),
        ShoppingItem(id: UUID(), name: "Lemon", category: "Produce", isPurchased: false)
    ]
}

#Preview {
    NavigationStack {
        ShoppingListView()
    }
}
