import SwiftUI
import Combine

struct InventoryListView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel = InventoryViewModel()
    @State private var searchText = ""
    @State private var isShowingFilters = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    EmptyStateView(
                        title: "No items yet",
                        message: "Start by scanning a barcode or manually adding your first ingredient."
                    ) {
                        viewModel.presentAddItem()
                    }
                } else {
                    inventoryList
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isShowingFilters.toggle()
                    } label: {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.presentAddItem()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .sheet(isPresented: $viewModel.isPresentingEditor) {
                InventoryEditorView(
                    draft: $viewModel.draft,
                    isSaving: viewModel.isSaving,
                    onSave: {
                        Task { await viewModel.saveDraft() }
                    },
                    onCancel: viewModel.dismissEditor
                )
            }
            .alert(item: $viewModel.alert) { error in
                Alert(title: Text("Something went wrong"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
            .task {
                await session.ensureSignedIn()
            }
            .onReceive(session.$householdID.combineLatest(session.$user)) { householdID, user in
                viewModel.updateSession(householdID: householdID, userID: user?.uid)
            }
            .sheet(isPresented: $isShowingFilters) {
                InventoryFilterSheet(isPresented: $isShowingFilters)
            }
        }
    }

    private var inventoryList: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    InventoryRowView(item: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(items: [item]) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        viewModel.presentEdit(for: item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.accentColor)
                }
            }
            .onDelete { offsets in
                let targets = offsets.map { filteredItems[$0] }
                Task { await viewModel.delete(items: targets) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await session.ensureSignedIn()
        }
    }

    private var filteredItems: [InventoryItem] {
        guard !searchText.isEmpty else { return viewModel.items }
        return viewModel.items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.category.localizedCaseInsensitiveContains(searchText)) ||
            (item.barcode?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

private struct InventoryFilterSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Toggle("Show expiring soon", isOn: .constant(true))
                    Toggle("Show out of stock", isOn: .constant(true))
                }

                Section("Categories") {
                    Text("Coming soon")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title3)
                .bold()
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: action) {
                Label("Add your first item", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
