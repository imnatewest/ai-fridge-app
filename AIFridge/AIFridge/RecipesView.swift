//
//  RecipesView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class RecipesViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isLoading: Bool = false
    @Published var recipeCards: [RecipeSummary] = []
    @Published var presentedRecipe: RecipeDetail?
    @Published var fallbackMessage: String?
    private let service: AIRecipesService
    private let inventoryProvider: () async -> [Item]
    private var imageLoadTask: Task<Void, Never>?

    struct RecipeDetail: Identifiable {
        let id: UUID
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let missingItems: [String]
    }

    init(service: AIRecipesService = .shared,
         inventoryProvider: @escaping () async -> [Item] = { [] }) {
        self.service = service
        self.inventoryProvider = inventoryProvider
        Task { await loadInitialRecipes() }
    }

    deinit {
        imageLoadTask?.cancel()
    }

    func requestSuggestions() async {
        guard !isLoading else { return }
        await loadRecipes(query: nil, allowFallback: true)
    }

    func search() async {
        guard !isLoading else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? nil : trimmed
        await loadRecipes(query: normalized, allowFallback: true)
    }

    func present(_ recipe: RecipeSummary) {
        presentedRecipe = RecipeDetail(
            id: recipe.id,
            title: recipe.title,
            ingredients: recipe.ingredients ?? Self.fallbackIngredients,
            instructions: recipe.instructions ?? Self.fallbackInstructions,
            missingItems: recipe.missingItems ?? (recipe.missingCount > 0 ? ["Missing ingredients from pantry"] : [])
        )
    }

    func addMissingIngredients(for recipe: RecipeDetail) {
        // TODO: Integrate shopping list sync.
    }

    func loadInitialRecipes() async {
        await loadRecipes(query: nil, allowFallback: true)
    }

    private func loadRecipes(query: String?, allowFallback: Bool) async {
        isLoading = true
        let inventory = await inventoryProvider()
        let result = await service.generateRecipes(query: query, inventory: inventory, limit: 6)
        recipeCards = result.recipes

        if result.usedFallback {
            fallbackMessage = "AI recipe service unavailable right now. Showing sample recipes instead."
        } else {
            fallbackMessage = nil
        }

        if recipeCards.isEmpty && allowFallback {
            recipeCards = RecipeSummary.samples
            if fallbackMessage == nil {
                fallbackMessage = "No AI recipes returned. Showing sample recipes instead."
            }
        }

        isLoading = false
        loadImagesForCurrentCards()
    }

    private func loadImagesForCurrentCards() {
        imageLoadTask?.cancel()
        let cards = recipeCards

        guard cards.contains(where: { $0.imageURL == nil }) else { return }

        imageLoadTask = Task {
            var updatedCards = cards

            for index in updatedCards.indices {
                guard !Task.isCancelled else { return }
                if updatedCards[index].imageURL != nil { continue }
                let title = updatedCards[index].title
                do {
                    if let url = try await PexelsImageService.shared.thumbnailURL(for: "food \(title)", size: .large) {
                        updatedCards[index].imageURL = url
                        await MainActor.run {
                            self.recipeCards[index].imageURL = url
                        }
                    }
                } catch {
                    continue
                }
            }
        }
    }

    private static let fallbackIngredients: [String] = [
        "2 cups seasonal vegetables",
        "1 protein of choice",
        "Fresh herbs",
        "Olive oil",
        "Sea salt"
    ]

    private static let fallbackInstructions: [String] = [
        "Preheat oven to 375°F (190°C).",
        "Toss ingredients with olive oil, salt, and spices.",
        "Roast or sauté until cooked through.",
        "Plate with fresh herbs and serve warm."
    ]
}

struct RecipesView: View {
    @StateObject private var viewModel = RecipesViewModel(
        inventoryProvider: RecipesView.makeInventoryProvider()
    )

    var body: some View {
        VStack(spacing: DesignSpacing.md) {
            searchBar

            ScrollView {
                LazyVStack(spacing: DesignSpacing.md, pinnedViews: [.sectionHeaders]) {
                    Section {
                        suggestionButton
                            .padding(.horizontal, DesignSpacing.md)
                    }

                    if let fallbackMessage = viewModel.fallbackMessage {
                        NotificationBannerView(
                            model: .init(
                                title: "Using sample recipes",
                                message: fallbackMessage,
                                style: .info
                            )
                        )
                        .padding(.horizontal, DesignSpacing.md)
                    }

                    if !viewModel.recipeCards.isEmpty {
                        Section(header: sectionHeader("Recommended")) {
                            ForEach(viewModel.recipeCards) { recipe in
                                RecipeCardView(recipe: recipe)
                                    .onTapGesture { viewModel.present(recipe) }
                                    .padding(.horizontal, DesignSpacing.md)
                            }
                        }
                    } else {
                        EmptyStateView(
                            title: "No recipes yet",
                            message: "Try requesting suggestions from your fridge contents."
                        )
                        .padding(.top, DesignSpacing.xl)
                    }
                }
                .padding(.top, DesignSpacing.sm)
            }
            .overlay { loadingOverlay }
        }
        .background(DesignPalette.background.ignoresSafeArea())
        .navigationTitle("Recipes")
        .sheet(item: $viewModel.presentedRecipe) { recipe in
            RecipeDetailView(
                recipe: recipe,
                onAddMissing: { viewModel.addMissingIngredients(for: recipe) }
            )
        }
    }

    private var searchBar: some View {
        HStack(spacing: DesignSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignPalette.secondaryText)
            TextField("What do you feel like eating?", text: $viewModel.query)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }
        }
        .padding(DesignSpacing.md)
        .background(DesignPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, DesignSpacing.md)
    }

    private var suggestionButton: some View {
        Button {
            Task { await viewModel.requestSuggestions() }
        } label: {
            Label("Suggest Meals From My Fridge", systemImage: "wand.and.stars")
                .font(DesignTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DesignPalette.accentMint.gradient)
                )
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Requests AI meal ideas using your current inventory.")
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(DesignTypography.subheadline)
                .foregroundStyle(DesignPalette.secondaryText)
            Spacer()
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.xs)
        .background(DesignPalette.background)
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            ZStack {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView("Cooking up ideas…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .transition(.opacity)
        }
    }
}

private extension RecipesView {
    static func makeInventoryProvider() -> () async -> [Item] {
        let db = Firestore.firestore()

        return {
            await withCheckedContinuation { continuation in
                db.collection("items").getDocuments { snapshot, error in
                    guard error == nil, let documents = snapshot?.documents else {
                        continuation.resume(returning: [])
                        return
                    }

                    let items = documents.compactMap { document -> Item? in
                        try? document.data(as: Item.self)
                    }
                    continuation.resume(returning: items)
                }
            }
        }
    }
}

extension RecipeSummary {
    static let samples: [RecipeSummary] = [
        RecipeSummary(
            id: UUID(),
            title: "Creamy Lemon Pasta with Spinach",
            imageURL: nil,
            usedCount: 3,
            missingCount: 1,
            durationText: "25 min",
            ingredients: [
                "200g linguine",
                "1 lemon",
                "2 cups spinach",
                "¼ cup grated parmesan",
                "2 cloves garlic"
            ],
            instructions: [
                "Cook pasta until al dente and reserve half a cup of pasta water.",
                "Sauté garlic in olive oil, add lemon zest and juice.",
                "Toss pasta with sauce, spinach, parmesan, and pasta water until creamy."
            ],
            missingItems: ["Parmesan cheese"]
        ),
        RecipeSummary(
            id: UUID(),
            title: "Sheet Pan Salmon & Veggies",
            imageURL: nil,
            usedCount: 4,
            missingCount: 0,
            durationText: "30 min",
            ingredients: [
                "2 salmon fillets",
                "1 cup cherry tomatoes",
                "1 zucchini",
                "1 red onion",
                "2 tbsp olive oil"
            ],
            instructions: [
                "Preheat oven to 400°F (200°C).",
                "Toss vegetables with olive oil and spread on sheet pan.",
                "Add salmon, season, and roast for 16-18 minutes."
            ]
        ),
        RecipeSummary(
            id: UUID(),
            title: "Spiced Chickpea Buddha Bowl",
            imageURL: nil,
            usedCount: 5,
            missingCount: 2,
            durationText: "35 min",
            ingredients: [
                "1 can chickpeas",
                "2 cups cooked quinoa",
                "1 avocado",
                "Mixed greens",
                "Tahini dressing"
            ],
            instructions: [
                "Roast chickpeas with spices until crispy.",
                "Assemble bowls with quinoa, greens, roasted chickpeas, and sliced avocado.",
                "Drizzle with tahini dressing."
            ],
            missingItems: ["Tahini", "Avocado"]
        )
    ]
}

// MARK: - Supporting Views
private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(DesignPalette.accent.opacity(0.6))
            Text(title)
                .font(DesignTypography.title)
            Text(message)
                .font(DesignTypography.body)
                .foregroundStyle(DesignPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct RecipeDetailView: View {
    let recipe: RecipesViewModel.RecipeDetail
    let onAddMissing: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.lg) {
                Text(recipe.title)
                    .font(DesignTypography.display)

                if !recipe.missingItems.isEmpty {
                    NotificationBannerView(
                        model: .init(
                            title: "Missing ingredients",
                            message: recipe.missingItems.joined(separator: ", "),
                            style: .warning
                        )
                    )
                    Button("Add missing to shopping list", action: onAddMissing)
                        .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    Text("Ingredients")
                        .font(DesignTypography.headline)
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        Label(ingredient, systemImage: "checkmark.circle")
                            .font(DesignTypography.body)
                    }
                }

                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    Text("Instructions")
                        .font(DesignTypography.headline)
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: DesignSpacing.sm) {
                            Text("\(index + 1).")
                                .font(DesignTypography.caption)
                                .foregroundStyle(DesignPalette.secondaryText)
                            Text(step)
                                .font(DesignTypography.body)
                        }
                    }
                }
            }
            .padding(DesignSpacing.lg)
        }
        .presentationDetents([.large, .medium])
    }
}

#Preview {
    NavigationStack {
        RecipesView()
    }
}
