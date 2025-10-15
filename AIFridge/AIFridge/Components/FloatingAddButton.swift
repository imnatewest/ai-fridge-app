//
//  FloatingAddButton.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(DesignPalette.accent.gradient)
                )
                .designShadow(DesignShadow.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add item")
        .accessibilityHint("Opens the add item form")
    }
}

#Preview {
    FloatingAddButton {}
        .padding()
        .background(Color.black.opacity(0.1))
}
