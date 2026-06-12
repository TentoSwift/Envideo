import SwiftUI

/// ローカル動画 → AVPlayer / YouTube動画 → YTSwiftyPlayer に分岐
struct FullScreenPlayerWrapper: View {
    let item: HistoryItem
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let playerController: PlayerController
    let onProgress: (String, Double) -> Void
    let onDuration: (String, Double) -> Void
    let onSelect: (HistoryItem) -> Void
    let onAdd: (URL) -> Void
    let onEnded: (String) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        switch item.kind {
        case .local:
            FullScreenPlayerView(
                item: item,
                videoHistory: videoHistory,
                thumbnails: thumbnails,
                positions: positions,
                durations: durations,
                playerController: playerController,
                onProgress: onProgress,
                onDuration: onDuration,
                onSelect: onSelect,
                onAdd: onAdd,
                onEnded: onEnded,
                isPresented: $isPresented
            )
        case .youtube:
            YouTubeFullScreenView(
                item: item,
                videoHistory: videoHistory,
                thumbnails: thumbnails,
                positions: positions,
                durations: durations,
                onProgress: onProgress,
                onDuration: onDuration,
                onSelect: onSelect,
                isPresented: $isPresented
            )
        }
    }
}

/// YouTube動画を全画面で再生する SwiftUI ビュー
/// Up Next と 座席ピッカー(イマーシブ時のみ) のオーバーレイ付き
struct YouTubeFullScreenView: View {
    let item: HistoryItem
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let onProgress: (String, Double) -> Void
    let onDuration: (String, Double) -> Void
    let onSelect: (HistoryItem) -> Void
    @Binding var isPresented: Bool

    @State private var cinemaState = CinemaState.shared
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let videoID = item.youtubeID {
                YouTubePlayerView(
                    videoID: videoID,
                    itemKey: item.key,
                    initialPosition: positions[item.key] ?? 0,
                    onProgress: onProgress,
                    onDuration: onDuration,
                    onEnded: {
                        // 位置を0にリセット保存して履歴に戻る
                        onProgress(item.key, 0)
                        Task { @MainActor in
                            if cinemaState.isImmersiveOpen {
                                await dismissImmersiveSpace()
                            }
                            isPresented = false
                        }
                    }
                )
                .ignoresSafeArea()
            }

            // 閉じるボタン (左上)
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .padding(16)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
            .buttonStyle(.plain)

            // 下部のオーナメント: イマーシブ環境内でのみ Up Next + 座席を表示
            if cinemaState.isImmersiveOpen {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Up Next")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                            UpNextView(
                                videoHistory: videoHistory,
                                thumbnails: thumbnails,
                                positions: positions,
                                durations: durations,
                                selectedKey: item.key,
                                onSelect: onSelect,
                                onAddTapped: { /* not used here */ }
                            )
                        }
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("座席")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                            SeatPickerView()
                        }
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}
