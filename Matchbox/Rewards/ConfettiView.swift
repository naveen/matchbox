import SwiftUI

/// A burst of confetti from the centre whenever `trigger` changes.
struct ConfettiView: View {
    let trigger: Int

    @State private var startedAt: Date?

    private let colors: [Color] = [.pink, .orange, .yellow, .green, .cyan, .purple, .mint, .red]

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                guard let startedAt else { return }
                let t = timeline.date.timeIntervalSince(startedAt)
                guard t < 2.2 else { return }
                var random = SeededRandom(seed: UInt64(max(trigger, 1)))
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                for _ in 0..<90 {
                    let angle = random.next() * .pi * 2
                    let speed = 250 + random.next() * 500
                    let vx = cos(angle) * speed
                    let vy = sin(angle) * speed - 300
                    let x = origin.x + vx * t
                    let y = origin.y + vy * t + 700 * t * t
                    let spin = random.next() * 10
                    let w = 8 + random.next() * 10
                    let h = 6 + random.next() * 8
                    let color = colors[Int(random.next() * Double(colors.count)) % colors.count]
                    let alpha = max(0, 1 - t / 2.2)
                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(t * spin))
                    piece.fill(Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h)), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in startedAt = .now }
    }
}

/// Deterministic random numbers so every frame of a burst agrees with the last.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
