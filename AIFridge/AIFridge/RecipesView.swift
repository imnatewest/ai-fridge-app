//
//  RecipesView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import Combine

@MainActor
final class RecipesViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isLoading: Bool = false
    @Published var recipeCards: [RecipeSummary] = RecipeSummary.samples
    @Published var presentedRecipe: RecipeDetail?
    private var imageLoadTask: Task<Void, Never>?

    struct RecipeDetail: Identifiable {
        let id: UUID
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let missingItems: [String]
    }

    func requestSuggestions() async {
        guard !isLoading else { return }
        isLoading = true

        // TODO: Integrate AI request. Simulate delay for now.
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }

    func search() async {
        guard !isLoading else { return }
        isLoading = true
        // TODO: Integrate search call.
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }

    func present(_ recipe: RecipeSummary) {
        presentedRecipe = RecipeDetail(
            id: recipe.id,
            title: recipe.title,
            ingredients: [
                "200g linguine",
                "1 lemon",
                "2 cups spinach",
                "¼ cup grated parmesan",
                "2 cloves garlic"
            ],
            instructions: [
                "Bring a large pot of salted water to boil. Cook pasta until al dente.",
                "Meanwhile, sauté garlic in olive oil until fragrant.",
                "Stir in lemon zest, juice, and cream. Simmer gently.",
                "Toss pasta with sauce, spinach, and parmesan until coated.",
                "Serve warm with extra parmesan and cracked pepper."
            ],
            missingItems: recipe.missingCount > 0 ? ["Parmesan cheese"] : []
        )
    }

    func addMissingIngredients(for recipe: RecipeDetail) {
        // TODO: Integrate shopping list sync.
    }

    init() {
        loadImagesForCurrentCards()
    }

    deinit {
        imageLoadTask?.cancel()
    }

    private func loadImagesForCurrentCards() {
        imageLoadTask?.cancel()
        let cards = recipeCards

        imageLoadTask = Task {
            var updatedCards = cards

            for index in updatedCards.indices {
                guard !Task.isCancelled else { return }
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
}

struct RecipesView: View {
    @StateObject private var viewModel = RecipesViewModel()

    var body: some View {
        VStack(spacing: DesignSpacing.md) {
            searchBar

            ScrollView {
                LazyVStack(spacing: DesignSpacing.md, pinnedViews: [.sectionHeaders]) {
                    Section {
                        suggestionButton
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

private extension RecipeSummary {
    static let samples: [RecipeSummary] = [
        RecipeSummary(
            id: UUID(),
            title: "Creamy Lemon Pasta with Spinach",
            imageURL: nil,
            usedCount: 3,
            missingCount: 1,
            durationText: "25 min"
        ),
        RecipeSummary(
            id: UUID(),
            title: "Sheet Pan Salmon & Veggies",
            imageURL: nil,
            usedCount: 4,
            missingCount: 0,
            durationText: "30 min"
        ),
        RecipeSummary(
            id: UUID(),
            title: "Spiced Chickpea Buddha Bowl",
            imageURL: nil,
            usedCount: 5,
            missingCount: 2,
            durationText: "35 min"
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
