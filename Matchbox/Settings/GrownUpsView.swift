import SwiftUI

/// The parent-facing screen: what every trackpad gesture is currently mapped
/// to on this Mac, read live from the system preferences.
struct GrownUpsView: View {
    @State private var settings: [TrackpadSetting] = []
    private let reader = TrackpadSettingsReader()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Mac's trackpad settings")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Read from System Settings for the account that is logged in. Matchbox only reads these; change them in System Settings.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { load() }
                Button("Open System Settings", systemImage: "gearshape") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], alignment: .leading, spacing: 16) {
                    ForEach(TrackpadSetting.Section.allCases) { section in
                        Section {
                            ForEach(settings.filter { $0.section == section }) { setting in
                                SettingCard(setting: setting)
                            }
                        } header: {
                            Text(section.rawValue)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        settings = reader.read()
    }
}

private struct SettingCard: View {
    let setting: TrackpadSetting

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: setting.symbol)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(
                    (setting.isOn ? Color.accentColor : Color.secondary).opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .foregroundStyle(setting.isOn ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(setting.title)
                    .font(.system(.headline, design: .rounded))
                Text(setting.value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(setting.isOn ? Color.primary : Color.secondary)
                Text(setting.hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
