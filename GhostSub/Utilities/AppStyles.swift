import SwiftUI

// This creates the interactive press/hover effect you asked for
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
