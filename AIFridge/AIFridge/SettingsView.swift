//
//  SettingsView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var aiReceiptEnabled = true
    @State private var aiRecipesEnabled = true

    var body: some View {
        Form {
            Section("Profile") {
                NavigationLink {
                    Text("Household sharing coming soon.")
                        .padding()
                } label: {
                    Label("Household Sharing", systemImage: "person.3.fill")
                }
            }

            Section("Notifications") {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Expiration alerts", systemImage: "bell.badge.fill")
                }
            }

            Section("AI Options") {
                Toggle(isOn: $aiReceiptEnabled) {
                    Label("Receipt OCR", systemImage: "doc.viewfinder")
                }
                Toggle(isOn: $aiRecipesEnabled) {
                    Label("Recipe generation", systemImage: "wand.and.stars")
                }
            }

            Section("Privacy") {
                Button {
                    // TODO: Export data.
                } label: {
                    Label("Export data", systemImage: "square.and.arrow.up")
                }
                .foregroundColor(DesignPalette.accent)

                Button(role: .destructive) {
                    // TODO: Delete data.
                } label: {
                    Label("Delete data", systemImage: "trash")
                }
            }

            Section {
                Button("Sign out") {
                    // TODO: Sign out flow.
                }
                .foregroundColor(DesignPalette.danger)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
