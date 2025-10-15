//
//  FilterChips.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct FilterChips<Option: Hashable & Identifiable>: View where Option: CustomStringConvertible {
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSpacing.sm) {
                ForEach(options) { option in
                    chip(for: option)
                }
            }
            .padding(.vertical, DesignSpacing.xs)
        }
    }

    private func chip(for option: Option) -> some View {
        Button {
            selection = option
        } label: {
            Text(option.description)
                .font(DesignTypography.body)
                .padding(.horizontal, DesignSpacing.md)
                .padding(.vertical, DesignSpacing.xs)
                .background(
                    Capsule()
                        .fill(selection == option ? DesignPalette.accent.opacity(0.15) : DesignPalette.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(selection == option ? DesignPalette.accent : DesignPalette.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.description)
    }
}

#Preview {
    struct Option: Hashable, Identifiable, CustomStringConvertible {
        let id: UUID
        let name: String
        var description: String { name }
    }

    struct Wrapper: View {
        @State private var selection = Option(id: UUID(), name: "All")
        private let sample = [
            Option(id: UUID(), name: "All"),
            Option(id: UUID(), name: "Expiring Soon"),
            Option(id: UUID(), name: "Favorites")
        ]

        var body: some View {
            FilterChips(selection: $selection, options: sample)
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    return Wrapper()
}
