import SwiftUI

struct KeyboardToolbar: ViewModifier {
    @FocusState var focusedField: Bool

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = false
                    }
                }
            }
    }
}

extension View {
    func keyboardToolbar(focused: FocusState<Bool>.Binding) -> some View {
        self.modifier(KeyboardToolbar())
    }
}
