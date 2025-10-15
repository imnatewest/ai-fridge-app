//
//  DesignShadow.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI

enum DesignShadow {
    /// Soft card shadow for elevated surfaces.
    static let card = Shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Apply a predefined `Shadow` from the design system.
    func designShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
