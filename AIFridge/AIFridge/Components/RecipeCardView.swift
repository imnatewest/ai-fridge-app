//
//  RecipeCardView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct RecipeSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let imageURL: URL?
    let usedCount: Int
    let missingCount: Int
    let durationText: String?
}

struct RecipeCardView: View {
    let recipe: RecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: recipe.imageURL) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.15)
                            .overlay(ProgressView().progressViewStyle(.circular))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.15)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.largeTitle)
                                    .foregroundColor(DesignPalette.accent.opacity(0.6))
                            )
                    @unknown default:
                        Color.gray.opacity(0.15)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let durationText = recipe.durationText {
                    Label(durationText, systemImage: "clock")
                        .font(DesignTypography.caption)
                        .padding(.horizontal, DesignSpacing.sm)
                        .padding(.vertical, DesignSpacing.xxs)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(DesignSpacing.sm)
                }
            }

            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(recipe.title)
                    .font(DesignTypography.title)
                    .foregroundStyle(DesignPalette.primaryText)
                    .lineLimit(2)

                HStack(spacing: DesignSpacing.sm) {
                    Label("\(recipe.usedCount) in fridge", systemImage: "checkmark.seal.fill")
                        .font(DesignTypography.caption)
                        .foregroundStyle(DesignPalette.accent)

                    if recipe.missingCount > 0 {
                        Label("Missing \(recipe.missingCount)", systemImage: "cart.badge.plus")
                            .font(DesignTypography.caption)
                            .foregroundStyle(DesignPalette.secondaryText)
                    } else {
                        Label("All set", systemImage: "sparkles")
                            .font(DesignTypography.caption)
                            .foregroundStyle(DesignPalette.secondaryText)
                    }
                }
            }
        }
        .padding(DesignSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DesignPalette.accent.opacity(0.08), lineWidth: 1)
        )
        .designShadow(DesignShadow.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title). Uses \(recipe.usedCount) from your fridge\(recipe.missingCount > 0 ? ", missing \(recipe.missingCount)" : "")")
    }
}

#Preview {
    RecipeCardView(
        recipe: RecipeSummary(
            id: UUID(),
            title: "Creamy Lemon Pasta with Spinach",
            imageURL: URL(string: "https://picsum.photos/400/240"),
            usedCount: 3,
            missingCount: 1,
            durationText: "25 min"
        )
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
