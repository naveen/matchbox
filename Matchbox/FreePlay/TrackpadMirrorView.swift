import SwiftUI

/// Draws a trackpad-shaped outline with one glowing dot per finger, so the
/// child can see exactly what the trackpad sees.
struct TrackpadMirrorView: View {
    let state: TouchState

    private let dotColors: [Color] = [.pink, .orange, .yellow, .green, .cyan, .purple, .mint, .indigo]

    var body: some View {
        GeometryReader { geo in
            let size = fittedSize(in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.accentColor.opacity(state.pressure * 0.35))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        state.isPressed ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: state.isPressed ? 6 : 3
                    )

                ForEach(Array(state.fingers.enumerated()), id: \.element.id) { index, finger in
                    Circle()
                        .fill(dotColors[index % dotColors.count].gradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: dotColors[index % dotColors.count].opacity(0.7), radius: 18)
                        .position(x: finger.x * size.width, y: (1 - finger.y) * size.height)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size.width, height: size.height)
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.interactiveSpring(duration: 0.12), value: state.fingers)
            .animation(.easeOut(duration: 0.15), value: state.isPressed)
        }
    }

    private func fittedSize(in bounds: CGSize) -> CGSize {
        let aspect = state.trackpadAspect
        if bounds.width / bounds.height > aspect {
            return CGSize(width: bounds.height * aspect, height: bounds.height)
        }
        return CGSize(width: bounds.width, height: bounds.width / aspect)
    }
}
