import SwiftUI
import AVKit

extension ContentView {

    func playFromBeginning(_ item: HistoryItem) {
        savePosition(key: item.key, seconds: 0)

        if selectedItem?.key == item.key {
            playerController.seek(to: 0)
            playerController.play()
            return
        }

        selectedItem = item

        DispatchQueue.main.async {
            self.playerController.seek(to: 0)
            self.playerController.play()
        }
    }

    @ViewBuilder
    func historyRow1(_ item: HistoryItem) -> some View {
        let saved = positions[item.key] ?? 0
        if let thumb = thumbnails[item.key] {
            Button {
                selectedItem = item
            } label: {
                thumb
                    .resizable()
                    .scaledToFill()
                    .frame(width: 290.4, height: 163.35)
                    .clipped()
                    .cornerRadius(15)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.thickMaterial)
                            .opacity(selectedItem?.key == item.key ? 0.7 : 0)
                    }
                    .overlay(alignment: .center) {
                        if selectedItem?.key == item.key {
                            Image("apple.nowplaying")
                                .foregroundStyle(.white)
                                .font(.system(size: 50))
                                .opacity(0.7)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let total = durations[item.key], total > 0 {
                            historyCardInfo(item: item, saved: saved, total: total)
                        }
                    }
            }
            .buttonStyle(CustomButtonStyle())
            .contextMenu {
                if item.key != selectedItem?.key {
                    Button("削除", systemImage: "trash", role: .destructive) {
                        deleteHistory(item)
                    }
                }
                Button("最初から再生", systemImage: "gobackward") {
                    playFromBeginning(item)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.gray.opacity(0.3))
                .frame(width: 290.4, height: 163.35)
                .onAppear {
                    if thumbnails[item.key] == nil {
                        generateThumbnail(for: item)
                    }
                }
                .overlay {
                    if selectedItem?.key == item.key {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.thickMaterial.opacity(0.7))
                    }
                }
                .overlay(alignment: .center) {
                    if selectedItem?.key == item.key {
                        Image("apple.nowplaying")
                            .foregroundStyle(.white)
                            .font(.system(size: 50))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let total = durations[item.key], total > 0 {
                        historyCardInfo(item: item, saved: saved, total: total)
                    }
                }
                .onTapGesture { selectedItem = item }
                .contextMenu {
                    if item.key != selectedItem?.key {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            deleteHistory(item)
                        }
                    }
                    Button("最初から再生", systemImage: "gobackward") {
                        playFromBeginning(item)
                    }
                }
        }
    }

    @ViewBuilder
    func historyRow(_ item: HistoryItem) -> some View {
        let saved = positions[item.key] ?? 0

        Button {
            selectedItem = item
        } label: {
            HStack(spacing: 10) {
                thumbnailCell(item: item, saved: saved)
                VStack(alignment: .leading) {
                    Text(item.displayName)
                        .lineLimit(1)
                    if let total = durations[item.key], total > 0 {
                        Text("\(formatTime(saved)) / \(formatTime(total))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: saved, total: total)
                            .tint(.gray)
                    }
                }
                Spacer()
            }
        }
        .swipeActions {
            if selectedItem?.key != item.key {
                Button("削除", systemImage: "trash", role: .destructive) {
                    deleteHistory(item)
                }
                .labelStyle(.titleOnly)
            }
        }
    }

    // MARK: - Private subviews

    @ViewBuilder
    private func historyCardInfo(item: HistoryItem, saved: Double, total: Double) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.displayName)
                    .lineLimit(1)
                    .fontWeight(.bold)
                    .font(.caption)
                Spacer()
                if item.key == selectedItem?.key {
                    Text("\(formatTime(saved)) / \(formatTime(total))")
                        .font(.system(.caption, design: .rounded))
                } else {
                    Text("\(Int(total / 60))分")
                        .font(.system(.caption, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            ProgressView(value: saved, total: total)
                .tint(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 13)
        .padding(.top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 15,
                bottomTrailingRadius: 15,
                topTrailingRadius: 0
            )
            .fill(.ultraThickMaterial)
            .environment(\.colorScheme, .light)
            .mask {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.8), location: 0.5),
                        .init(color: .black, location: 0.6),
                        .init(color: .white, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(item: HistoryItem, saved: Double) -> some View {
        let isSelected = selectedItem?.key == item.key
        Group {
            if let thumb = thumbnails[item.key] {
                thumb.resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .onAppear {
                        if thumbnails[item.key] == nil {
                            generateThumbnail(for: item)
                        }
                    }
            }
        }
        .frame(width: 80, height: 45)
        .clipped()
        .cornerRadius(6)
        .overlay {
            if isSelected {
                Rectangle().fill(.thickMaterial.opacity(0.1))
            }
        }
        .overlay(alignment: .center) {
            if isSelected {
                Image("apple.nowplaying").foregroundStyle(.white)
            }
        }
    }
}
