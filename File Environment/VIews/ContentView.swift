import SwiftUI
import AVKit
import UniformTypeIdentifiers
internal import Combine

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 17)
                    .fill(.thinMaterial)
                    .opacity(configuration.isPressed ? 1.0 : 0.0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .hoverEffect(.highlight)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject var playerController = PlayerController()
    @AppStorage("videoHistoryBookmarks") var historyData: Data = Data()
    @AppStorage("videoPositionsByBookmarkKey") var positionsData: Data = Data()
    @AppStorage("videoDurationsByBookmarkKey") var durationsData: Data = Data()

    @State var thumbnails: [String: Image] = [:]
    @State var videoHistory: [HistoryItem] = []
    @State var positions: [String: Double] = [:]
    @State var durations: [String: Double] = [:]

    @State var selectedItem: HistoryItem? = nil
    @State var isImporterPresented = false
    @State var aspectRatio: CGFloat = 9/16
    @State var isFullScreen = false
    @State var isDisplayHistory: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let item = selectedItem, let url = item.url {
                    PlayerContainerView(
                        url: url,
                        initialPosition: positions[item.key] ?? 0,
                        onProgress: { savePosition(key: item.key, seconds: $0) },
                        onDuration: { saveDuration(key: item.key, seconds: $0) },
                        onAspectRatio: { aspectRatio = $0 },
                        playerController: playerController
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1 / aspectRatio, contentMode: .fit)
                    .cornerRadius(10)
                    .id(item.key)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            withAnimation { isDisplayHistory = false }
                        }
                    )
                } else if videoHistory.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("動画がありません")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Button {
                            isImporterPresented.toggle()
                        } label: {
                            Label("動画を追加", systemImage: "plus")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("再生履歴") {
                            ForEach(videoHistory) { item in
                                historyRow(item)
                            }
                        }
                        Section {
                            Button("動画を追加", systemImage: "plus") {
                                isImporterPresented.toggle()
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .ornament(visibility: .visible, attachmentAnchor: .scene(.bottom)) {
                bottomBar
            }
            .onAppear {
                loadHistory()
                loadPositions()
                loadDurations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .updateThumbnail)) { _ in
                guard let item = selectedItem else { return }
                thumbnails[item.key] = nil
                generateThumbnail(for: item)
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.movie],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    addToHistoryAndSelect(url)
                }
            }
        }
        .onTapGesture {
            withAnimation { isDisplayHistory = false }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let player = playerController.player {
                FullScreenPlayerView(
                    player: player,
                    videoHistory: videoHistory,
                    thumbnails: thumbnails,
                    positions: positions,
                    durations: durations,
                    selectedKey: selectedItem?.key,
                    onSelect: { item in
                        playerController.player?.pause()
                        selectedItem = item
                    },
                    isPresented: $isFullScreen
                )
            }
        }
    }

    // MARK: - Bottom ornament

    @ViewBuilder
    private var bottomBar: some View {
        VStack(alignment: .center) {
            HStack {
                if let item = selectedItem {
                    playbackControls(item: item)
                } else {
                    Button {
                        isImporterPresented.toggle()
                    } label: {
                        Label("動画を追加", systemImage: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 850)
            .frame(maxHeight: 50)
            .padding()
            .glassBackgroundEffect()
            .clipShape(Capsule())

            if isDisplayHistory {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(videoHistory) { item in
                            historyRow1(item)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollInputBehavior(.enabled, for: .look)
                .contentMargins(.horizontal, 20)
                .frame(width: 1000)
                .frame(height: 250)
                .scrollIndicators(.hidden)
                .glassBackgroundEffect()
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    @ViewBuilder
    private func playbackControls(item: HistoryItem) -> some View {
        HStack {
            Button { playerController.skip(by: -15) } label: {
                Label("15秒戻す", systemImage: "gobackward.15")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 28))
                    .fontWeight(.semibold)
                    .padding()
            }
            .buttonStyle(.plain)

            Button { playerController.toggle() } label: {
                Label(
                    playerController.isPlaying ? "停止" : "再生",
                    systemImage: playerController.isPlaying ? "pause.fill" : "play.fill"
                )
                .contentTransition(.symbolEffect(.replace))
                .labelStyle(.iconOnly)
                .font(.system(size: 40))
                .fontWeight(.semibold)
                .padding()
            }
            .buttonStyle(.plain)

            Button { playerController.skip(by: 15) } label: {
                Label("15秒スキップ", systemImage: "goforward.15")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 28))
                    .fontWeight(.semibold)
                    .padding()
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)

        VStack(alignment: .leading) {
            Spacer()
            Text(item.displayName)
                .lineLimit(1)
                .padding(.bottom, 10)
                .padding(.leading, 10)
            if playerController.duration > 0 {
                Slider(
                    value: $playerController.currentTime,
                    in: 0...playerController.duration,
                    onEditingChanged: { editing in
                        if !editing { playerController.seek(to: playerController.currentTime) }
                    }
                )
                .tint(.gray.mix(with: .white, by: 0.9).opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: 10)
            }
            Spacer()
        }
        .padding(.trailing)
        .padding(.bottom)

        Button { isFullScreen = true } label: {
            Label("全画面", systemImage: "arrow.up.left.and.arrow.down.right")
                .labelStyle(.iconOnly)
                .font(.system(size: 30))
                .fontWeight(.semibold)
                .padding()
        }
        .buttonStyle(.plain)

        Button {
            withAnimation { isImporterPresented.toggle() }
        } label: {
            Label("追加", systemImage: "plus")
                .fontWeight(.semibold)
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .bold()
                .padding()
        }
        .buttonStyle(.plain)

        Button {
            withAnimation { isDisplayHistory.toggle() }
        } label: {
            ZStack {
                if isDisplayHistory {
                    Capsule()
                        .fill(.white)
                        .frame(width: 70, height: 55)
                    Label("履歴", systemImage: "list.bullet")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .labelStyle(.iconOnly)
                        .font(.largeTitle)
                        .bold()
                        .padding()
                        .blendMode(.destinationOut)
                } else {
                    Label("履歴", systemImage: "list.bullet")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .labelStyle(.iconOnly)
                        .font(.largeTitle)
                        .bold()
                        .padding()
                }
            }
            .compositingGroup()
        }
        .buttonStyle(.plain)
    }
}
