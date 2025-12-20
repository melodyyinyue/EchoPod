import SwiftUI

struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(.white)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.primaryGradient)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(pressed ? 0.25 : 0.15))
                        .blur(radius: pressed ? 1 : 3)
                        .blendMode(.overlay)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: AppTheme.primary.opacity(0.35), radius: pressed ? 4 : 8, x: 0, y: pressed ? 1 : 6)
            .scaleEffect(pressed ? 0.96 : 1)
            .offset(y: pressed ? 1 : 0)
            .animation(.interpolatingSpring(stiffness: 260, damping: 18), value: pressed)
    }
}
