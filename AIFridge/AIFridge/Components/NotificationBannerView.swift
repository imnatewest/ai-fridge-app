//
//  NotificationBannerView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

struct NotificationBannerModel: Identifiable, Equatable {
    enum Style {
        case success
        case warning
        case info
    }

    let id = UUID()
    let title: String
    let message: String
    let style: Style
}

struct NotificationBannerView: View {
    let model: NotificationBannerModel

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: DesignSpacing.xxs) {
                Text(model.title)
                    .font(DesignTypography.body)
                    .foregroundColor(DesignPalette.primaryText)
                Text(model.message)
                    .font(DesignTypography.caption)
                    .foregroundColor(DesignPalette.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        )
        .designShadow(DesignShadow.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.title). \(model.message)")
    }

    private var iconName: String {
        switch model.style {
        case .success: return "leaf.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch model.style {
        case .success: return DesignPalette.success
        case .warning: return DesignPalette.warning
        case .info: return DesignPalette.accent
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        NotificationBannerView(
            model: .init(
                title: "Everything fresh!",
                message: "No expired items detected. Keep it up 🌱",
                style: .success
            )
        )

        NotificationBannerView(
            model: .init(
                title: "3 items expiring soon",
                message: "Milk, Spinach, Berries will expire in the next 2 days.",
                style: .warning
            )
        )
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
