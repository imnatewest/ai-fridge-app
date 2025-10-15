//
//  DesignTypography.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

enum DesignTypography {
    /// Large display style for hero sections.
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)

    /// Prominent title for cards and section headers.
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)

    /// Headline for primary text blocks.
    static let headline = Font.system(.headline, design: .rounded)

    /// Subheadline for supportive labels.
    static let subheadline = Font.system(.subheadline, design: .rounded)

    /// Default body font for descriptive text.
    static let body = Font.system(.body, design: .rounded)

    /// Secondary caption for metadata and labels.
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)

    /// Smallest supporting text.
    static let mini = Font.system(.footnote, design: .rounded)
}
