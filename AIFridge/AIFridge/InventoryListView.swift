//
//  InventoryListView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

enum InventoryViewMode: String, CaseIterable {
    case grid = "Cards"
    case list = "List"
}

enum SortOption: String, CaseIterable {
    case expirationSoon = "Expiring Soon"
    case quantityHigh = "Quantity"
    case recentlyAdded = "Recently Added"
}

enum InventoryFilter: String, CaseIterable, Identifiable, CustomStringConvertible {
    case all = "All"
    case expiringSoon = "Expiring Soon"
    case favorites = "Favorites"

    var id: Self { self }
    var description: String { rawValue }
}

struct InventoryListView: View {
    @State private var items: [Item] = []
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    @State private var sortOption: SortOption = .expirationSoon
    @State private var selectedCategory: String = "All"
    @State private var viewMode: InventoryViewMode = .grid
    @State private var filter: InventoryFilter = .all
    @State private var lastSyncDate: Date?
    @State private var listener: ListenerRegistration?

    let db = Firestore.firestore()

    init(previewItems: [Item]? = nil) {
        if let previewItems {
            _items = State(initialValue: previewItems)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch viewMode {
                    case .grid:
                        gridContent
                    case .list:
                        listContent
                    }
                }
                .animation(.easeInOut, value: viewMode)

                FloatingAddButton {
                    showingAddItem = true
                }
                .padding(.trailing, DesignSpacing.lg)
                .padding(.bottom, DesignSpacing.lg)
            }
            .background(DesignPalette.background.ignoresSafeArea())
            .navigationTitle("My Fridge")
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item)
            }
            .onAppear {
                listenToInventory()
            }
            .onDisappear {
                stopListening()
            }
        }
    }
}

// MARK: - Layout Content
private extension InventoryListView {
    var categoriesForFilter: [String] {
        let unique = uniqueCategories
        if unique.contains("All") {
            return unique
        } else {
            return ["All"] + unique
        }
    }

    var heroItem: Item? {
        filteredAndSortedItems
            .filter { daysUntilExpiration(for: $0) >= 0 }
            .min { $0.expirationDate < $1.expirationDate }
    }

    var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: DesignSpacing.md),
         GridItem(.flexible(), spacing: DesignSpacing.md)]
    }

    @ViewBuilder
    func headerStack(includeHero: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            headerView

            FilterChips(
                selection: $filter,
                options: InventoryFilter.allCases
            )

            InventoryFilterBar(
                sortOption: $sortOption,
                selectedCategory: $selectedCategory,
                viewMode: $viewMode,
                categories: categoriesForFilter
            )

            if let banner = bannerModel {
                NotificationBannerView(model: banner)
            }

            if includeHero, let item = heroItem {
                InventoryHeroBanner(
                    item: item,
                    daysRemaining: daysUntilExpiration(for: item),
                    color: colorFor(item: item),
                    onUse: { useItem(item) },
                    onSnooze: { snoozeItem(item) }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text(greeting)
                .font(DesignTypography.title)
            Text(summaryLine)
                .font(DesignTypography.body)
                .foregroundStyle(DesignPalette.secondaryText)
            Text(lastSyncText)
                .font(DesignTypography.caption)
                .foregroundStyle(DesignPalette.secondaryText.opacity(0.8))
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var summaryLine: String {
        if items.isEmpty {
            return "Add your first items to start tracking freshness."
        }

        return "\(expiringSoonCount) expiring soon • \(expiredCount) expired"
    }

    private var lastSyncText: String {
        guard let lastSyncDate else {
            return "Syncing with Firestore…"
        }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        let relative = relativeFormatter.localizedString(for: lastSyncDate, relativeTo: Date())
        return "Last synced \(relative)"
    }

    private var bannerModel: NotificationBannerModel? {
        guard !items.isEmpty else { return nil }

        if expiringSoonCount == 0 && expiredCount == 0 {
            return NotificationBannerModel(
                title: "Everything fresh!",
                message: "No items are expiring soon. Nice work!",
                style: .success
            )
        }

        if expiringSoonCount > 0 {
            let names = expiringSoonItems.prefix(3).map(\.name).joined(separator: ", ")
            let extra = expiringSoonCount > 3 ? " +\(expiringSoonCount - 3) more" : ""
            return NotificationBannerModel(
                title: "\(expiringSoonCount) item\(expiringSoonCount == 1 ? "" : "s") expiring soon",
                message: names.isEmpty ? "Check the expiring soon section." : "\(names)\(extra)",
                style: .warning
            )
        }

        return nil
    }

    private var expiringSoonItems: [Item] {
        items.filter { (0...3).contains(daysUntilExpiration(for: $0)) }
    }

    private var expiringSoonCount: Int {
        expiringSoonItems.count
    }

    private var expiredCount: Int {
        items.filter { daysUntilExpiration(for: $0) < 0 }.count
    }

    @ViewBuilder
    var gridContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.lg) {
                headerStack(includeHero: true)

                ForEach(sectionedItems, id: \.title) { section in
                    if !section.items.isEmpty {
                        InventorySectionGridView(
                            title: section.title,
                            count: section.items.count,
                            items: section.items,
                            columns: gridColumns,
                            iconForItem: iconName(for:),
                            colorForItem: colorFor(item:),
                            badgeTextForItem: badgeText(for:),
                            subtitleForItem: subtitle(for:),
                            daysUntil: { daysUntilExpiration(for: $0) },
                            onSelect: { selectedItem = $0 },
                            onUse: useItem,
                            onSnooze: snoozeItem,
                            onDelete: deleteItem
                        )
                    }
                }
            }
            .padding(.horizontal, DesignSpacing.md)
            .padding(.bottom, DesignSpacing.xl)
        }
    }

    @ViewBuilder
    var listContent: some View {
        List {
            ForEach(sectionedItems, id: \.title) { section in
                if !section.items.isEmpty {
                    Section {
                        ForEach(section.items) { item in
                            InventoryListRow(
                                item: item,
                                iconName: iconName(for: item),
                                badgeText: badgeText(for: item),
                                subtitle: subtitle(for: item),
                                color: colorFor(item: item),
                                isUrgent: isUrgent(item)
                            )
                            .onTapGesture {
                                selectedItem = item
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    useItem(item)
                                } label: {
                                    Label("Use", systemImage: "minus.circle")
                                }
                                .tint(.blue)

                                Button {
                                    snoozeItem(item)
                                } label: {
                                    Label("Snooze", systemImage: "clock.arrow.circlepath")
                                }

                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            deleteItems(at: offsets, in: section.items)
                        }
                    } header: {
                        InventorySectionHeader(title: section.title, count: section.items.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            headerStack(includeHero: true)
                .padding(.horizontal, DesignSpacing.md)
                .padding(.bottom, DesignSpacing.md)
                .background(DesignPalette.background)
        }
    }
}

// MARK: - Firestore
private extension InventoryListView {
    func listenToInventory() {
        listener?.remove()
        listener = db.collection("items")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("❌ Error loading items: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found in Firestore.")
                    items = []
                    lastSyncDate = Date()
                    return
                }

                items = documents.compactMap { doc in
                    try? doc.data(as: Item.self)
                }
                lastSyncDate = Date()

                print("✅ Loaded \(items.count) items")
                ExpirationNotificationScheduler.shared.syncNotifications(with: items)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - Helpers
private extension InventoryListView {
    var filteredAndSortedItems: [Item] {
        var filtered = items

        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        switch filter {
        case .all:
            break
        case .expiringSoon:
            filtered = filtered.filter { (0...3).contains(daysUntilExpiration(for: $0)) }
        case .favorites:
            filtered = filtered.filter { $0.category?.lowercased() == "favorites" }
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

    var uniqueCategories: [String] {
        let categories = items.compactMap { $0.category }
        return Array(Set(categories)).sorted()
    }

    var sectionedItems: [(title: String, items: [Item])] {
        let expired = filteredAndSortedItems.filter { daysUntilExpiration(for: $0) < 0 }
        let soon = filteredAndSortedItems.filter { (0...3).contains(daysUntilExpiration(for: $0)) }
        let later = filteredAndSortedItems.filter { daysUntilExpiration(for: $0) > 3 }

        var sections: [(String, [Item])] = []
        if !expired.isEmpty { sections.append(("Expired", expired)) }
        if !soon.isEmpty { sections.append(("Expiring Soon", soon)) }
        if !later.isEmpty { sections.append(("Later", later)) }
        return sections
    }

    func deleteItems(at offsets: IndexSet, in sectionItems: [Item]) {
        let itemsToDelete = offsets.map { sectionItems[$0] }
        deleteItems(itemsToDelete)
    }

    func deleteItems(_ itemsToDelete: [Item]) {
        withAnimation(.easeInOut) {
            for item in itemsToDelete {
                deleteItem(item)
            }
        }
    }

    func deleteItem(_ item: Item) {
        guard let id = item.id else { return }
        ExpirationNotificationScheduler.shared.cancelNotification(for: id)
        db.collection("items").document(id).delete { error in
            if let error {
                print("❌ Error deleting item: \(error)")
            } else {
                print("🗑️ Deleted item: \(item.name)")
            }
        }
    }

    func daysUntilExpiration(for item: Item, from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfExpiry = calendar.startOfDay(for: item.expirationDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return components.day ?? 0
    }

    func colorFor(item: Item) -> Color {
        let days = daysUntilExpiration(for: item)
        if days < 0 {
            return DesignPalette.danger
        } else if days <= 3 {
            return DesignPalette.warning
        } else {
            return DesignPalette.accent
        }
    }

    func badgeText(for item: Item) -> String {
        let days = daysUntilExpiration(for: item)
        if days < 0 {
            return "Expired"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }

    func isUrgent(_ item: Item) -> Bool {
        let days = daysUntilExpiration(for: item)
        return (0...3).contains(days)
    }

    func subtitle(for item: Item) -> String {
        let days = daysUntilExpiration(for: item)
        if days <= 3 {
            return urgentSubtitle(for: item)
        } else {
            return "Expires \(item.expirationDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    func urgentSubtitle(for item: Item) -> String {
        let days = daysUntilExpiration(for: item)
        if days < 0 { return "Expired" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    func iconName(for item: Item) -> String {
        switch item.category?.lowercased() {
        case "dairy": return "carton"
        case "produce": return "leaf"
        case "meat": return "flame"
        case "frozen": return "snow"
        case "bakery": return "bagel"
        case "beverage": return "cup.and.saucer"
        default: return "square.grid.2x2"
        }
    }

    func useItem(_ item: Item) {
        guard let id = item.id else { return }
        var newQuantity = item.quantity - 1
        if newQuantity < 0 { newQuantity = 0 }
        db.collection("items").document(id).updateData(["quantity": newQuantity]) { error in
            if let error { print("❌ Error updating quantity: \(error)") }
        }
    }

    func snoozeItem(_ item: Item) {
        guard let id = item.id else { return }
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: item.expirationDate) ?? item.expirationDate
        db.collection("items").document(id).updateData(["expirationDate": newDate]) { error in
            if let error { print("❌ Error snoozing expiration: \(error)") }
        }
    }
}

// MARK: - Subviews
private struct InventoryFilterBar: View {
    @Binding var sortOption: SortOption
    @Binding var selectedCategory: String
    @Binding var viewMode: InventoryViewMode

    let categories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            HStack(spacing: DesignSpacing.sm) {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("View Mode", selection: $viewMode) {
                ForEach(InventoryViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct InventorySectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DesignTypography.caption)
                .foregroundColor(DesignPalette.secondaryText)
            Spacer()
            Text("\(count)")
                .font(DesignTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSpacing.xs)
    }
}

private struct InventorySectionGridView: View {
    let title: String
    let count: Int
    let items: [Item]
    let columns: [GridItem]
    let iconForItem: (Item) -> String
    let colorForItem: (Item) -> Color
    let badgeTextForItem: (Item) -> String
    let subtitleForItem: (Item) -> String
    let daysUntil: (Item) -> Int
    let onSelect: (Item) -> Void
    let onUse: (Item) -> Void
    let onSnooze: (Item) -> Void
    let onDelete: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            InventorySectionHeader(title: title, count: count)

            LazyVGrid(columns: columns, spacing: DesignSpacing.md) {
                ForEach(items) { item in
                    InventoryItemCard(
                        item: item,
                        iconName: iconForItem(item),
                        badgeText: badgeTextForItem(item),
                        subtitle: subtitleForItem(item),
                        daysRemaining: daysUntil(item),
                        cardColor: colorForItem(item),
                        onSelect: { onSelect(item) },
                        onUse: { onUse(item) },
                        onSnooze: { onSnooze(item) },
                        onDelete: { onDelete(item) }
                    )
                }
            }
        }
    }
}

private struct InventoryItemCard: View {
    let item: Item
    let iconName: String
    let badgeText: String
    let subtitle: String
    let daysRemaining: Int
    let cardColor: Color
    let onSelect: () -> Void
    let onUse: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                HStack {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(cardColor)
                    Spacer()
                    StatusBadge(text: badgeText, color: cardColor, isUrgent: daysRemaining <= 3 && daysRemaining >= 0)
                }

                Text(item.name)
                    .font(DesignTypography.title)
                    .foregroundColor(DesignPalette.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(DesignTypography.caption)
                    .foregroundColor(DesignPalette.secondaryText)

                HStack {
                    Text("\(Int(item.quantity)) \(item.unit)")
                        .font(DesignTypography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let category = item.category {
                        Text(category.capitalized)
                            .font(DesignTypography.caption)
                            .foregroundColor(cardColor)
                    }
                }
            }
            .padding(DesignSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(cardColor.opacity(0.15), lineWidth: 1)
            )
            .designShadow(DesignShadow.card)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onUse()
            } label: {
                Label("Use", systemImage: "minus.circle")
            }

            Button {
                onSnooze()
            } label: {
                Label("Snooze 1 day", systemImage: "clock.arrow.circlepath")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct InventoryListRow: View {
    let item: Item
    let iconName: String
    let badgeText: String
    let subtitle: String
    let color: Color
    let isUrgent: Bool

    var body: some View {
        HStack(spacing: DesignSpacing.sm) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSpacing.xs) {
                    Text(item.name)
                        .font(DesignTypography.body)
                    StatusBadge(text: badgeText, color: color, isUrgent: isUrgent)
                }

                HStack(spacing: DesignSpacing.xs) {
                    Text("\(Int(item.quantity)) \(item.unit)")
                        .foregroundStyle(.secondary)
                        .font(DesignTypography.caption)
                    Text(subtitle)
                        .font(DesignTypography.caption)
                        .foregroundColor(DesignPalette.secondaryText)
                }
            }
        }
        .padding(.vertical, DesignSpacing.xs)
    }
}

private struct InventoryHeroBanner: View {
    let item: Item
    let daysRemaining: Int
    let color: Color
    let onUse: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text("Next to use")
                .font(DesignTypography.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(item.name)
                .font(DesignTypography.display)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(heroSubtitle)
                .font(DesignTypography.body)
                .foregroundColor(.white.opacity(0.9))

            HStack(spacing: DesignSpacing.sm) {
                Button {
                    onUse()
                } label: {
                    Label("Use now", systemImage: "checkmark.circle.fill")
                        .font(DesignTypography.body)
                        .padding(.vertical, DesignSpacing.xs)
                        .padding(.horizontal, DesignSpacing.md)
                        .background(.white.opacity(0.15), in: Capsule())
                }

                Button {
                    onSnooze()
                } label: {
                    Label("Snooze 1 day", systemImage: "clock.arrow.circlepath")
                        .font(DesignTypography.body)
                        .padding(.vertical, DesignSpacing.xs)
                        .padding(.horizontal, DesignSpacing.md)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
        }
        .padding(DesignSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.95),
                    color.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .designShadow(DesignShadow.card)
    }

    private var heroSubtitle: String {
        if daysRemaining < 0 {
            return "Already expired — check before using."
        } else if daysRemaining == 0 {
            return "Expires today. Time to create something delicious!"
        } else if daysRemaining == 1 {
            return "1 day remaining. Plan a recipe tonight."
        } else {
            return "Expires in \(daysRemaining) days."
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color
    let isUrgent: Bool

    var body: some View {
        Text(text)
            .font(DesignTypography.caption)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSpacing.xs)
            .padding(.vertical, DesignSpacing.xxs)
            .background(
                Capsule().fill(color.opacity(isUrgent ? 0.95 : 0.7))
            )
    }
}

#Preview {
    // Seeded preview items: expired, today, 2 days, 7 days
    let calendar = Calendar.current
    let today = Date()
    let makeItem: (String, Int) -> Item = { name, daysFromNow in
        let expiry = calendar.date(byAdding: .day, value: daysFromNow, to: today) ?? today
        return Item(
            id: UUID().uuidString,
            name: name,
            category: "Produce",
            quantity: 1,
            unit: "pc",
            expirationDate: expiry,
            timestamp: Date()
        )
    }

    return InventoryListView(previewItems: [
        makeItem("Milk (expired)", -1),
        makeItem("Eggs (today)", 0),
        makeItem("Lettuce (2 days)", 2),
        makeItem("Tomatoes (7 days)", 7)
    ])
}
