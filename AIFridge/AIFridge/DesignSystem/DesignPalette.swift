//
//  DesignPalette.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import UIKit

enum DesignPalette {
    /// Primary background color for app surfaces.
    static let background = Color.named("AppBackground", fallback: Color(uiColor: .systemBackground))

    /// Elevated card background.
    static let surface = Color(uiColor: .secondarySystemBackground)

    /// Secondary elevated surface for contrast.
    static let surfaceAlt = Color(uiColor: .tertiarySystemBackground)

    /// Accent color for highlights and primary actions.
    static let accent = Color.named("BadgeAccent", fallback: .blue)

    /// Mint accent used for positive states and CTA buttons.
    static let accentMint = Color(uiColor: UIColor(red: 0.19, green: 0.71, blue: 0.62, alpha: 1.0))

    /// Warning color for soon-to-expire items.
    static let warning = Color.named("WarningOrange", fallback: .orange)

    /// Critical color for expired items.
    static let danger = Color.named("ExpiredRed", fallback: .red)

    /// Subtle separator color for cards and dividers.
    static let separator = Color(uiColor: .systemGray5)

    /// Primary text color that adapts with light/dark appearance.
    static let primaryText = Color.primary

    /// Secondary text color for supportive information.
    static let secondaryText = Color.secondary

    /// Success color for celebratory messages.
    static let success = Color(uiColor: UIColor(red: 0.36, green: 0.74, blue: 0.36, alpha: 1.0))
}
