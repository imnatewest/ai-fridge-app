//
//  InventoryListView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import Foundation
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
    @StateObject private var imageLoader = IngredientImageLoader()

    let db = Firestore.firestore()

    init(previewItems: [Item]? = nil) {
        if let previewItems {
            _items = State(initialValue: previewItems)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                DesignPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSpacing.lg) {
                        InventoryModernHeader(
                            greeting: greeting,
                            summary: summaryLine,
                            syncStatus: lastSyncText,
                            heroItem: heroItem,
                            daysUntil: { daysUntilExpiration(for: $0) },
                            colorForItem: colorFor(item:),
                            onUse: useItem,
                            onSnooze: snoozeItem,
                            imageURL: imageURL(for:),
                            requestImage: requestImage(for:)
                        )
                        .padding(.horizontal, DesignSpacing.lg)
                        .padding(.top, DesignSpacing.lg)

                        VStack(spacing: DesignSpacing.lg) {
                            SummaryStatRow(
                                expiringSoon: expiringSoonCount,
                                expired: expiredCount,
                                total: items.count
                            )

                            FilterSection(
                                filter: $filter,
                                sortOption: $sortOption,
                                selectedCategory: $selectedCategory,
                                viewMode: $viewMode,
                                categories: categoriesForFilter
                            )

                            if let banner = bannerModel {
                                NotificationBannerView(model: banner)
                            }

            ModernInventorySection(
                sections: sectionedItems,
                viewMode: viewMode,
                iconForItem: iconName(for:),
                colorForItem: colorFor(item:),
                                badgeTextForItem: badgeText(for:),
                                daysUntil: { daysUntilExpiration(for: $0) },
                                shouldShowExpiration: shouldShowExpirationNotice(for:),
                                imageURLForItem: imageURL(for:),
                                requestImage: requestImage(for:),
                                onSelect: { selectedItem = $0 },
                                onUse: useItem,
                                onSnooze: snoozeItem,
                                onDelete: deleteItem
                            )
                        }
                        .padding(.horizontal, DesignSpacing.lg)
                        .padding(.bottom, DesignSpacing.xl)
                    }
                }

                FloatingAddButton {
                    showingAddItem = true
                }
                .padding(.trailing, DesignSpacing.lg)
                .padding(.bottom, DesignSpacing.lg)
            }
            .toolbarTitleDisplayMode(.inline)
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
                imageLoader.cancelAll()
            }
        }
    }
}

// MARK: - Firestore
private extension InventoryListView {
    func listenToInventory() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            imageLoader.prepare(with: items)
            return
        }
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
                imageLoader.prepare(with: items)

                print("✅ Loaded \(items.count) items")
                ExpirationNotificationScheduler.shared.syncNotifications(with: items)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

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

    var bannerModel: NotificationBannerModel? {
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

    var expiringSoonItems: [Item] {
        items.filter { (0...3).contains(daysUntilExpiration(for: $0)) }
    }

    var expiringSoonCount: Int {
        expiringSoonItems.count
    }

    var expiredCount: Int {
        items.filter { daysUntilExpiration(for: $0) < 0 }.count
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    var summaryLine: String {
        if items.isEmpty {
            return "Add your first items to start tracking freshness."
        }

        return "\(expiringSoonCount) expiring soon • \(expiredCount) expired"
    }

    var lastSyncText: String {
        guard let lastSyncDate else {
            return "Syncing with Firestore…"
        }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        let relative = relativeFormatter.localizedString(for: lastSyncDate, relativeTo: Date())
        return "Last synced \(relative)"
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

    func shouldShowExpirationNotice(for item: Item) -> Bool {
        daysUntilExpiration(for: item) <= 7
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

    func imageURL(for item: Item) -> URL? {
        imageLoader.url(for: item)
    }

    func requestImage(for item: Item) {
        imageLoader.loadIfNeeded(for: item)
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
private struct InventoryModernHeader: View {
    let greeting: String
    let summary: String
    let syncStatus: String
    let heroItem: Item?
    let daysUntil: (Item) -> Int
    let colorForItem: (Item) -> Color
    let onUse: (Item) -> Void
    let onSnooze: (Item) -> Void
    let imageURL: (Item) -> URL?
    let requestImage: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(greeting)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(summary)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text(syncStatus)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            if let heroItem {
                HeroItemCard(
                    item: heroItem,
                    daysRemaining: daysUntil(heroItem),
                    tint: colorForItem(heroItem),
                    onUse: { onUse(heroItem) },
                    onSnooze: { onSnooze(heroItem) },
                    imageURL: imageURL(heroItem),
                    requestImage: { requestImage(heroItem) }
                )
            }
        }
        .padding(DesignSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.33, blue: 0.80),
                    Color(red: 0.11, green: 0.52, blue: 0.87)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)
    }
}

private struct HeroItemCard: View {
    let item: Item
    let daysRemaining: Int
    let tint: Color
    let onUse: () -> Void
    let onSnooze: () -> Void
    let imageURL: URL?
    let requestImage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            HStack(alignment: .center, spacing: DesignSpacing.sm) {
                FoodThumbnailView(imageURL: imageURL, iconName: "fork.knife", tint: .white.opacity(0.85), size: 54)
                    .onAppear(perform: requestImage)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(item.name)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(heroSubtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                StatusBadge(text: badgeText, color: tint, isUrgent: true)
            }

            HStack(spacing: DesignSpacing.sm) {
                Button {
                    onUse()
                } label: {
                    Label("Use now", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, DesignSpacing.xs)
                        .padding(.horizontal, DesignSpacing.md)
                        .background(Color.white.opacity(0.2), in: Capsule())
                }

                Button {
                    onSnooze()
                } label: {
                    Label("Snooze 1 day", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, DesignSpacing.xs)
                        .padding(.horizontal, DesignSpacing.md)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
            }
        }
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

    private var badgeText: String {
        if daysRemaining < 0 {
            return "Expired"
        } else if daysRemaining == 0 {
            return "Today"
        } else if daysRemaining == 1 {
            return "1 day"
        } else {
            return "\(daysRemaining) days"
        }
    }
}

private struct SummaryStatRow: View {
    let expiringSoon: Int
    let expired: Int
    let total: Int

    var body: some View {
        HStack(spacing: DesignSpacing.sm) {
            SummaryStatCard(
                title: "Expiring Soon",
                value: "\(expiringSoon)",
                icon: "timer",
                tint: DesignPalette.warning
            )

            SummaryStatCard(
                title: "Expired",
                value: "\(expired)",
                icon: "exclamationmark.octagon.fill",
                tint: DesignPalette.danger
            )

            SummaryStatCard(
                title: "Total Items",
                value: "\(total)",
                icon: "refrigerator.fill",
                tint: DesignPalette.accent
            )
        }
    }
}

private struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            HStack(spacing: DesignSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignPalette.secondaryText)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(DesignPalette.primaryText)
        }
        .padding(DesignSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignPalette.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 10)
    }
}

private struct FilterSection: View {
    @Binding var filter: InventoryFilter
    @Binding var sortOption: SortOption
    @Binding var selectedCategory: String
    @Binding var viewMode: InventoryViewMode

    let categories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            FilterChips(
                selection: $filter,
                options: InventoryFilter.allCases
            )

            HStack(spacing: DesignSpacing.sm) {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    ControlPill(title: sortOption.rawValue, systemImage: "arrow.up.arrow.down.circle")
                }

                Menu {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } label: {
                    ControlPill(title: selectedCategory, systemImage: "tag")
                }

                Spacer(minLength: 0)
            }

            Picker("", selection: $viewMode) {
                ForEach(InventoryViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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

private struct ExpiringSoonCarousel: View {
    let items: [Item]
    let daysUntil: (Item) -> Int
    let iconForItem: (Item) -> String
    let colorForItem: (Item) -> Color
    let imageURLForItem: (Item) -> URL?
    let onSelect: (Item) -> Void
    let requestImage: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            HStack {
                Text("Expiring Soon")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text("See \(items.count > 1 ? "all" : "details")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignPalette.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.md) {
                    ForEach(items) { item in
                        ExpiringSoonCard(
                            item: item,
                            daysRemaining: daysUntil(item),
                            tint: colorForItem(item),
                            imageURL: imageURLForItem(item),
                            iconName: iconForItem(item),
                            onSelect: { onSelect(item) },
                            requestImage: { requestImage(item) }
                        )
                    }
                }
                .padding(.vertical, DesignSpacing.xs)
            }
        }
    }
}

private struct ExpiringSoonCard: View {
    let item: Item
    let daysRemaining: Int
    let tint: Color
    let imageURL: URL?
    let iconName: String
    let onSelect: () -> Void
    let requestImage: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                FoodThumbnailView(imageURL: imageURL, iconName: iconName, tint: tint, size: 60)
                    .onAppear(perform: requestImage)

                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignPalette.primaryText)
                        .lineLimit(1)
                }

                Spacer()

                HStack {
                    StatusBadge(text: statusText, color: tint, isUrgent: true)
                    Spacer()
                    Text("\(Int(item.quantity)) \(item.unit)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignSpacing.md)
            .frame(width: 200, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if daysRemaining < 0 {
            return "Expired"
        } else if daysRemaining == 0 {
            return "Today"
        } else if daysRemaining == 1 {
            return "Tomorrow"
        } else {
            return "In \(daysRemaining)d"
        }
    }
}

private struct ModernInventorySection: View {
    let sections: [(title: String, items: [Item])]
    let viewMode: InventoryViewMode
    let iconForItem: (Item) -> String
    let colorForItem: (Item) -> Color
    let badgeTextForItem: (Item) -> String
    let daysUntil: (Item) -> Int
    let shouldShowExpiration: (Item) -> Bool
    let imageURLForItem: (Item) -> URL?
    let requestImage: (Item) -> Void
    let onSelect: (Item) -> Void
    let onUse: (Item) -> Void
    let onSnooze: (Item) -> Void
    let onDelete: (Item) -> Void

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: DesignSpacing.md),
         GridItem(.flexible(), spacing: DesignSpacing.md)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            ForEach(sections, id: \.title) { section in
                if !section.items.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        HStack {
                            Text(section.title)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("\(section.items.count)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        if viewMode == .grid {
                            LazyVGrid(columns: gridColumns, spacing: DesignSpacing.md) {
                                ForEach(section.items) { item in
                                    InventoryItemCard(
                                        item: item,
                                        iconName: iconForItem(item),
                                        badgeText: badgeTextForItem(item),
                                        daysRemaining: daysUntil(item),
                                        cardColor: colorForItem(item),
                                        imageURL: imageURLForItem(item),
                                        showExpiration: shouldShowExpiration(item),
                                        onSelect: { onSelect(item) },
                                        onUse: { onUse(item) },
                                        onSnooze: { onSnooze(item) },
                                        onDelete: { onDelete(item) }
                                    )
                                    .onAppear {
                                        requestImage(item)
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: DesignSpacing.sm) {
                                ForEach(section.items) { item in
                                    ModernInventoryRow(
                                        item: item,
                                        iconName: iconForItem(item),
                                        badgeText: badgeTextForItem(item),
                                        color: colorForItem(item),
                                        showExpiration: shouldShowExpiration(item),
                                        isUrgent: (0...3).contains(daysUntil(item)),
                                        imageURL: imageURLForItem(item),
                                        onSelect: { onSelect(item) },
                                        onUse: { onUse(item) },
                                        onSnooze: { onSnooze(item) },
                                        onDelete: { onDelete(item) }
                                    )
                                    .onAppear {
                                        requestImage(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ModernInventoryRow: View {
    let item: Item
    let iconName: String
    let badgeText: String
    let color: Color
    let showExpiration: Bool
    let isUrgent: Bool
    let imageURL: URL?
    let onSelect: () -> Void
    let onUse: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSpacing.sm) {
                FoodThumbnailView(imageURL: imageURL, iconName: iconName, tint: color, size: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    HStack(spacing: DesignSpacing.xs) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignPalette.primaryText)
                        Spacer()
                        if showExpiration {
                            StatusBadge(text: badgeText, color: color, isUrgent: isUrgent)
                        }
                    }

                    QuantityPill(text: "\(Int(item.quantity)) \(item.unit)", tint: color)
                }
            }
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(color.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onUse) {
                Label("Use", systemImage: "minus.circle")
            }

            Button(action: onSnooze) {
                Label("Snooze 1 day", systemImage: "clock.arrow.circlepath")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct ControlPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DesignSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, DesignSpacing.xs)
        .padding(.horizontal, DesignSpacing.md)
        .background(
            Capsule()
                .fill(DesignPalette.surface)
        )
        .overlay(
            Capsule()
                .stroke(DesignPalette.separator, lineWidth: 1)
        )
    }
}

private struct QuantityPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(tint)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(tint.opacity(0.15))
            )
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
    let daysUntil: (Item) -> Int
    let imageURLForItem: (Item) -> URL?
    let requestImage: (Item) -> Void
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
                        daysRemaining: daysUntil(item),
                        cardColor: colorForItem(item),
                        imageURL: imageURLForItem(item),
                        showExpiration: true,
                        onSelect: { onSelect(item) },
                        onUse: { onUse(item) },
                        onSnooze: { onSnooze(item) },
                        onDelete: { onDelete(item) }
                    )
                    .onAppear {
                        requestImage(item)
                    }
                }
            }
        }
    }
}

private struct InventoryItemCard: View {
    let item: Item
    let iconName: String
    let badgeText: String
    let daysRemaining: Int
    let cardColor: Color
    let imageURL: URL?
    let showExpiration: Bool
    let onSelect: () -> Void
    let onUse: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                HStack {
                    FoodThumbnailView(imageURL: imageURL, iconName: iconName, tint: cardColor, size: 48)
                    Spacer()
                    if showExpiration {
                        StatusBadge(text: badgeText, color: cardColor, isUrgent: daysRemaining <= 3 && daysRemaining >= 0)
                    }
                }

                Text(item.name)
                    .font(DesignTypography.title)
                    .foregroundColor(DesignPalette.primaryText)
                    .lineLimit(1)

                QuantityPill(text: "\(Int(item.quantity)) \(item.unit)", tint: cardColor)
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
    let color: Color
    let isUrgent: Bool
    let imageURL: URL?

    var body: some View {
        HStack(spacing: DesignSpacing.sm) {
            FoodThumbnailView(imageURL: imageURL, iconName: iconName, tint: color, size: 44)
                .overlay(
                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.8), lineWidth: 2)
                        ),
                    alignment: .bottomTrailing
                )
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

private struct FoodThumbnailView: View {
    let imageURL: URL?
    let iconName: String
    let tint: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(tint)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: iconName)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(tint)
                    @unknown default:
                        Image(systemName: iconName)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(tint)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .clipped()
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
            timestamp: Date(),
            barcode: nil
        )
    }

    return InventoryListView(previewItems: [
        makeItem("Milk (expired)", -1),
        makeItem("Eggs (today)", 0),
        makeItem("Lettuce (2 days)", 2),
        makeItem("Tomatoes (7 days)", 7)
    ])
}
