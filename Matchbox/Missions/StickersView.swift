import SwiftUI

/// Every sticker ever earned on this Mac.
struct StickersView: View {
    let book: StickerBook

    var body: some View {
        VStack(spacing: 20) {
            Text(book.stickers.isEmpty ? "No stickers yet" : "\(book.stickers.count) stickers")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .padding(.top, 30)
            if book.stickers.isEmpty {
                Text("Finish missions to earn them!")
                    .font(.system(size: 26, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], spacing: 14) {
                        ForEach(Array(book.stickers.enumerated()), id: \.offset) { _, sticker in
                            Text(sticker)
                                .font(.system(size: 64))
                                .frame(width: 110, height: 110)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                    .padding(30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.06))
    }
}
