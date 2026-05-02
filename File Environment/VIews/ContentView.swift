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
    @State var store = StoreManager()
    @AppStorage("videoHistoryBookmarks") var historyData: Data = Data()
    @AppStorage("videoPositionsByBookmarkKey") var positionsData: Data = Data()
    @AppStorage("videoDurationsByBookmarkKey") var durationsData: Data = Data()

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State var thumbnails: [String: Image] = [:]
    @State var videoHistory: [HistoryItem] = []
    @State var positions: [String: Double] = [:]
    @State var durations: [String: Double] = [:]

    @State var selectedItem: HistoryItem? = nil
    @State var isImporterPresented = false
    @State var isPaywallPresented = false
    @State var isFullScreen = false
    @State var isYouTubeAddPresented = false
    @State var isYouTubeBrowserPresented = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isOnboardingPresented = false
    @State private var didSetupRemoteCommands = false

    var body: some View {
        NavigationStack {
            Group {
                if videoHistory.isEmpty {
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
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 280), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(videoHistory) { item in
                                historyGridCard(item)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .padding(.top, 72)
                    }
                    .navigationTitle("再生履歴")
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
                if !didSetupRemoteCommands {
                    setupRemoteCommands()
                    didSetupRemoteCommands = true
                }
                if !hasSeenOnboarding {
                    isOnboardingPresented = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .updateThumbnail)) { _ in
                guard let item = selectedItem else { return }
                thumbnails[item.key] = nil
                generateThumbnail(for: item)
            }
            .onChange(of: store.isPurchased) { _, isPurchased in
                if !isPurchased { trimHistoryToLimit() }
            }
            .onChange(of: selectedItem) { _, item in
                isFullScreen = item != nil
            }
            .onChange(of: isFullScreen) { _, full in
                if !full {
                    playerController.player?.pause()
                    playerController.player?.replaceCurrentItem(with: nil)
                    selectedItem = nil
                }
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
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView().environment(store)
        }
        .sheet(isPresented: $isYouTubeAddPresented) {
            YouTubeAddView(isPresented: $isYouTubeAddPresented) { videoID, title in
                addYouTubeVideo(videoID: videoID, title: title)
            }
        }
        .sheet(isPresented: $isYouTubeBrowserPresented) {
            YouTubeBrowserView(isPresented: $isYouTubeBrowserPresented) { videoID, title in
                addYouTubeVideo(videoID: videoID, title: title)
            }
        }
        .sheet(isPresented: $isOnboardingPresented, onDismiss: {
            hasSeenOnboarding = true
        }) {
            OnboardingView(isPresented: $isOnboardingPresented)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let item = selectedItem {
                FullScreenPlayerWrapper(
                    item: item,
                    videoHistory: videoHistory,
                    thumbnails: thumbnails,
                    positions: positions,
                    durations: durations,
                    playerController: playerController,
                    onProgress: { savePosition(key: $0, seconds: $1) },
                    onDuration: { saveDuration(key: $0, seconds: $1) },
                    onSelect: { selectedItem = $0 },
                    onAdd: { addToHistoryAndSelect($0) },
                    onEnded: { _ in
                        savePosition(key: item.key, seconds: 0)
                        Task { @MainActor in
                            if CinemaState.shared.isImmersiveOpen {
                                await dismissImmersiveSpace()
                            }
                            isFullScreen = false
                        }
                    },
                    isPresented: $isFullScreen
                )
                .immersiveEnvironmentPicker {
                    Button {
                        Task {
                            await openImmersiveSpace(id: ImmersiveIDs.cinema)
                        }
                    } label: {
                        Label("シネマ", systemImage: "theatermasks.fill")
                    }
                    Button {
                        Task {
                            await openImmersiveSpace(id: ImmersiveIDs.studio)
                        }
                    } label: {
                        Label("スタジオ", systemImage: "film.stack.fill")
                    }
                }
            }
        }
    }

    // MARK: - Bottom ornament

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 4) {
            Button {
                isImporterPresented.toggle()
            } label: {
                Label("動画を追加", systemImage: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)

            Button {
                isYouTubeBrowserPresented = true
            } label: {
                Label("YouTubeを開く", systemImage: "play.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)

            Button {
                isYouTubeAddPresented = true
            } label: {
                Label("URLで追加", systemImage: "link")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: 50)
        .padding()
        .glassBackgroundEffect()
        .clipShape(Capsule())
    }
}
