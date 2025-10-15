//
//  RootTabView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            InventoryListView()
            .tabItem {
                Label("Inventory", systemImage: "refrigerator")
            }

            NavigationStack {
                RecipesView()
            }
            .tabItem {
                Label("Recipes", systemImage: "wand.and.stars")
            }

            NavigationStack {
                ShoppingListView()
            }
            .tabItem {
                Label("Shopping", systemImage: "checklist")
            }

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(DesignPalette.accent)
    }
}

#Preview {
    RootTabView()
}
