import SwiftUI

enum Room: String, CaseIterable, Identifiable {
    case missions = "Missions"
    case freePlay = "Free Play"
    case stickers = "Stickers"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .missions: "flag.checkered"
        case .freePlay: "hand.draw.fill"
        case .stickers: "star.fill"
        }
    }
}

struct ContentView: View {
    @State private var room: Room
    @State private var touchState = TouchState()
    @State private var book = StickerBook()
    @State private var session: MissionSession

    init(initialRoom: Room = .missions, profile: TrackpadProfile) {
        _room = State(initialValue: initialRoom)
        let book = StickerBook()
        _book = State(initialValue: book)
        _session = State(initialValue: MissionSession(profile: profile, book: book))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch room {
                case .missions: MissionsView(state: touchState, session: session)
                case .freePlay: FreePlayView(state: touchState)
                case .stickers: StickersView(book: book)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Label("Matchbox", systemImage: "hand.draw.fill")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
            Spacer()
            Picker("Room", selection: $room) {
                ForEach(Room.allCases) { room in
                    Label(room.rawValue, systemImage: room.symbol).tag(room)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
