//
//  InsightsView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import Charts
import Combine

struct InsightSnapshot {
    var saved: Double
    var wasted: Double
    var itemsUsed: Int
    var expiringSoon: Int
    var wasteByCategory: [WasteCategory]

    struct WasteCategory: Identifiable {
        let id = UUID()
        let category: String
        let amount: Double
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var snapshot = InsightSnapshot(
        saved: 42,
        wasted: 8,
        itemsUsed: 23,
        expiringSoon: 3,
        wasteByCategory: [
            .init(category: "Produce", amount: 5),
            .init(category: "Dairy", amount: 2),
            .init(category: "Bakery", amount: 1)
        ]
    )

    var celebrationBanner: NotificationBannerModel? {
        snapshot.expiringSoon == 0 ? NotificationBannerModel(
            title: "🎉 You saved everything this week!",
            message: "Keep tracking items to stay on top of your inventory.",
            style: .success
        ) : nil
    }
}

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.lg) {
                if let banner = viewModel.celebrationBanner {
                    NotificationBannerView(model: banner)
                        .padding(.horizontal, DesignSpacing.md)
                        .transition(.opacity)
                }

                statCards
                    .padding(.horizontal, DesignSpacing.md)

                wasteChart
                    .padding(.horizontal, DesignSpacing.md)

                Text("Keep scanning receipts and logging items so we can surface deeper insights about waste and savings.")
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignPalette.secondaryText)
                    .padding(.horizontal, DesignSpacing.md)
                    .padding(.bottom, DesignSpacing.xl)
            }
            .padding(.top, DesignSpacing.lg)
        }
        .background(DesignPalette.background.ignoresSafeArea())
        .navigationTitle("Insights")
    }

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSpacing.md) {
            StatCard(title: "$ Saved", value: "$\(Int(viewModel.snapshot.saved))")
            StatCard(title: "$ Wasted", value: "$\(Int(viewModel.snapshot.wasted))", color: DesignPalette.warning)
            StatCard(title: "Items Used", value: "\(viewModel.snapshot.itemsUsed)")
            StatCard(title: "Expiring Soon", value: "\(viewModel.snapshot.expiringSoon)", color: DesignPalette.warning)
        }
    }

    private var wasteChart: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text("Most Wasted Categories")
                .font(DesignTypography.headline)
            Chart(viewModel.snapshot.wasteByCategory) { item in
                BarMark(
                    x: .value("Amount", item.amount),
                    y: .value("Category", item.category)
                )
                .foregroundStyle(DesignPalette.danger.gradient)
                .annotation(position: .trailing) {
                    Text("\(Int(item.amount))")
                        .font(DesignTypography.caption)
                        .foregroundStyle(DesignPalette.secondaryText)
                }
            }
            .frame(height: 220)
            .chartXAxis(.hidden)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignPalette.surface)
        )
        .designShadow(DesignShadow.card)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var color: Color = DesignPalette.accentMint

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text(title)
                .font(DesignTypography.caption)
                .foregroundStyle(DesignPalette.secondaryText)
            Text(value)
                .font(DesignTypography.title)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignPalette.surface)
        )
        .designShadow(DesignShadow.card)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
