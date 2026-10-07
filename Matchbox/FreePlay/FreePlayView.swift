import SwiftUI

/// The sandbox: a finger mirror, a toy that reacts to every gesture, and a
/// running log of what the trackpad saw. There is no wrong way to play here.
struct FreePlayView: View {
    let state: TouchState

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                headline
                HStack(spacing: 24) {
                    TrackpadMirrorView(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(spacing: 16) {
                        ToyView(state: state)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        recentList
                    }
                    .frame(width: 340)
                }
                Text("Try one finger, two fingers, tapping, pressing hard, pinching, twisting…")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(28)

            // Must be on top so every trackpad event lands here.
            TouchCanvas(state: state)
        }
    }

    private var headline: some View {
        HStack(spacing: 14) {
            Image(systemName: state.headlineSymbol)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .contentTransition(.symbolEffect(.replace))
            Text(state.headline)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(height: 60)
        .animation(.snappy, value: state.headline)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What I saw")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
            ForEach(state.recent) { event in
                Label(event.text, systemImage: event.symbol)
                    .font(.system(.title3, design: .rounded))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: state.recent)
    }
}

/// A little car that scrolls around, grows with pinch, spins with rotate and
/// bounces on clicks.
private struct ToyView: View {
    let state: TouchState

    var body: some View {
        GeometryReader { geo in
            let offset = clamped(state.toyOffset, to: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
                Text(state.lastGesture == .forceClick ? "💥" : "🚗")
                    .font(.system(size: 96))
                    .scaleEffect(state.toyScale)
                    .rotationEffect(state.toyRotation)
                    .offset(offset)
                    .animation(.interactiveSpring(duration: 0.15), value: offset)
                    .animation(.bouncy, value: state.toyScale)
                    .animation(.interactiveSpring(duration: 0.15), value: state.toyRotation)
                    .keyframeAnimator(initialValue: 1.0, trigger: state.gestureSerial) { content, value in
                        content.scaleEffect(value)
                    } keyframes: { _ in
                        SpringKeyframe(0.85, duration: 0.08)
                        SpringKeyframe(1.0, duration: 0.25)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func clamped(_ offset: CGSize, to size: CGSize) -> CGSize {
        let limitX = max(0, size.width / 2 - 60)
        let limitY = max(0, size.height / 2 - 60)
        return CGSize(width: min(limitX, max(-limitX, offset.width)),
                      height: min(limitY, max(-limitY, offset.height)))
    }
}
