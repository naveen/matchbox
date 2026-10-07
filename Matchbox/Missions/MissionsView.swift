import SwiftUI

/// The main event: one mission at a time, a toy that reacts, a celebration,
/// and a finish line after a handful of missions.
struct MissionsView: View {
    let state: TouchState
    let session: MissionSession

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.06).ignoresSafeArea()

            switch session.phase {
            case .ready:
                ReadyView(session: session)
            case .playing, .celebrating:
                PlayingView(state: state, session: session)
                // Must be on top so every trackpad event lands here.
                TouchCanvas(state: state)
                ConfettiView(trigger: session.phase == .celebrating ? session.index + 1 : 0)
            case .finished:
                FinishedView(session: session)
            }
        }
        .onChange(of: state.gestureSerial) { _, _ in
            if let gesture = state.lastGesture { session.handle(gesture) }
        }
        .onChange(of: state.pointerTravel) { old, new in
            session.pointerMoved(by: new - old)
        }
    }
}

private struct ReadyView: View {
    let session: MissionSession

    var body: some View {
        VStack(spacing: 28) {
            Text("Ready?")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
            Text("\(MissionSession.missionsPerSession) missions. Every one you finish earns a sticker.")
                .font(.system(size: 26, design: .rounded))
                .foregroundStyle(.secondary)
            BigButton(title: "Start!", symbol: "play.fill") { session.start() }
            if !session.book.stickers.isEmpty {
                Text("You have \(session.book.stickers.count) stickers so far")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlayingView: View {
    let state: TouchState
    let session: MissionSession

    var body: some View {
        VStack(spacing: 0) {
            if let mission = session.current {
                VStack(spacing: 10) {
                    Text("Mission \(session.index + 1) of \(session.missions.count)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(session.phase == .celebrating ? "You did it!" : mission.prompt)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 1000)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: session.phase)
                }
                .padding(.top, 36)
                .padding(.horizontal, 40)

                Spacer()

                ToyStage(mission: mission, progress: session.progress, celebrating: session.phase == .celebrating)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                footer(for: mission)
                    .padding(.bottom, 28)
                    .padding(.horizontal, 40)
            }
        }
        .overlay {
            if !state.pointerInside {
                PointerNudge()
            }
        }
        .task(id: session.index) {
            try? await Task.sleep(for: MissionSession.hintDelay)
            if !Task.isCancelled, session.phase == .playing { session.showHint = true }
        }
    }

    @ViewBuilder
    private func footer(for mission: Mission) -> some View {
        HStack(spacing: 16) {
            StickerStrip(stickers: session.earned, total: session.missions.count)
            Spacer()
            if session.showHint, session.phase == .playing {
                Label(mission.hint, systemImage: mission.symbol)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .symbolEffect(.bounce, options: .repeating)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.bouncy, value: session.showHint)
    }
}

/// The emoji toy plus a progress ring. Continuous goals move, grow or spin
/// the toy as progress fills, so the child sees the gesture doing something.
private struct ToyStage: View {
    let mission: Mission
    let progress: Double
    let celebrating: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)

            Text(mission.emoji)
                .font(.system(size: 170))
                .scaleEffect(scale)
                .rotationEffect(rotation)
                .offset(offset)
                .animation(.bouncy, value: progress)
                .animation(.bouncy, value: celebrating)
        }
        .frame(width: 340, height: 340)
    }

    private var scale: CGFloat {
        if celebrating { return 1.3 }
        switch mission.goal {
        case .pinch(open: true): return 1 + progress * 0.6
        case .pinch(open: false): return 1 - progress * 0.5
        case .hold: return 1 - progress * 0.2
        default: return 1
        }
    }

    private var rotation: Angle {
        switch mission.goal {
        case .rotate(let clockwise): .degrees((clockwise ? 1 : -1) * progress * 360)
        case .moveArrow: .degrees(sin(progress * .pi * 6) * 12)
        default: .zero
        }
    }

    private var offset: CGSize {
        switch mission.goal {
        case .scroll(.up): CGSize(width: 0, height: -progress * 180)
        case .scroll(.down): CGSize(width: 0, height: progress * 180)
        case .scroll(.left): CGSize(width: -progress * 180, height: 0)
        case .scroll(.right): CGSize(width: progress * 180, height: 0)
        case .drag: CGSize(width: progress * 220, height: 0)
        case .forceClick: CGSize(width: 0, height: celebrating ? -260 : 0)
        default: .zero
        }
    }
}

private struct StickerStrip: View {
    let stickers: [String]
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { slot in
                ZStack {
                    Circle().fill(.thinMaterial).frame(width: 54, height: 54)
                    if slot < stickers.count {
                        Text(stickers[slot])
                            .font(.system(size: 34))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.bouncy, value: stickers)
    }
}

private struct PointerNudge: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down")
                .font(.system(size: 60, weight: .black))
                .symbolEffect(.bounce, options: .repeating)
            Text("Bring the arrow back in here!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
        }
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }
}

private struct FinishedView: View {
    let session: MissionSession

    var body: some View {
        VStack(spacing: 28) {
            Text("All done!")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
            Text("You earned \(session.earned.count) new stickers")
                .font(.system(size: 28, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                ForEach(Array(session.earned.enumerated()), id: \.offset) { _, sticker in
                    Text(sticker).font(.system(size: 80))
                }
            }
            .padding(.vertical, 10)
            BigButton(title: "Play again", symbol: "arrow.counterclockwise") { session.start() }
            Text("Your sticker book has \(session.book.stickers.count) stickers now")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct BigButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .padding(.horizontal, 44)
                .padding(.vertical, 20)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.extraLarge)
    }
}
