import SwiftUI

extension Color {
    /// Load a named color from asset catalog, with a SwiftUI Color fallback.
    /// Usage: Color.named("ExpiredRed", fallback: .red)
    static func named(_ name: String, fallback: Color) -> Color {
        if let uiColor = UIColor(named: name) {
            return Color(uiColor)
        } else {
            return fallback
        }
    }
}
