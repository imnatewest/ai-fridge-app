import SwiftUI

extension Binding where Value == String {
    /// Convert `Binding<String?>` -> `Binding<String>` for TextField.
    /// Writes empty strings back as `nil` to keep Firestore schema clean.
    init(unwrapping source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

extension Binding where Value == Double {
    /// Convert `Binding<Double?>` -> `Binding<Double>` for TextField with numbers.
    /// Writes 0 back as `nil` when appropriate.
    init(unwrapping source: Binding<Double?>, replacingNilWith defaultValue: Double) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = (newValue == defaultValue) ? nil : newValue
            }
        )
    }
}
