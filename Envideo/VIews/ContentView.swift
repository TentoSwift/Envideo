import SwiftUI
import AVKit
import PhotosUI
import StoreKit
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
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    /// App Store のレビュー作成ページ
    private static let writeReviewURL =
        URL(string: "https://apps.apple.com/app/id6779471160?action=write-review")!

    @State var thumbnails: [String: Image] = [:]
    @State var videoHistory: [HistoryItem] = []
    @State var positions: [String: Double] = [:]
    @State var durations: [String: Double] = [:]

    @State var selectedItem: HistoryItem? = nil
    @State var isImporterPresented = false
    @State var isPhotosPickerPresented = false
    @State var pickedPhotosItem: PhotosPickerItem? = nil
    @State var isPaywallPresented = false
    @State var isFullScreen = false
    @State var isYouTubeAddPresented = false
    @State var isYouTubeBrowserPresented = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false
    @State private var isOnboardingPresented = false
    @State private var didSetupRemoteCommands = false
    @State private var updateChecker = UpdateChecker()
    #if canImport(VLCKit)
    @State private var showVLCTest = false
    #endif

    var body: some View {
        mainContent
            .task { await updateChecker.check() }
            // 強制アップデート: 閉じられない sheet で表示。背後の ornament も隠して
            // 操作を完全に塞ぐ(setter を空にして外部からの dismiss も無効化)
            .sheet(isPresented: Binding(get: { updateChecker.updateRequired },
                                        set: { _ in })) {
                UpdateRequiredView(appStoreURL: updateChecker.appStoreURL)
                    .interactiveDismissDisabled()
            }
    }

    private var mainContent: some View {
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
                        addVideoMenu {
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
            .ornament(visibility: updateChecker.updateRequired ? .hidden : .visible,
                      attachmentAnchor: .scene(.bottom)) {
                bottomBar
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openURL(Self.writeReviewURL)
                    } label: {
                        Label("レビューを書く", systemImage: "star.bubble")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPaywallPresented = true
                    } label: {
                        Label("Envideo Pro",
                              systemImage: store.isPurchased ? "crown.fill" : "crown")
                    }
                }
                #if canImport(VLCKit)
                ToolbarItem(placement: .topBarLeading) {
                    Button("VLC") { showVLCTest = true }
                }
                #endif
            }
            #if canImport(VLCKit)
            .sheet(isPresented: $showVLCTest) { VLCTestView() }
            #endif
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
            .photosPicker(
                isPresented: $isPhotosPickerPresented,
                selection: $pickedPhotosItem,
                matching: .videos,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: pickedPhotosItem) { _, newItem in
                guard let newItem else { return }
                if let identifier = newItem.itemIdentifier {
                    addPhotoLibraryVideo(assetID: identifier)
                }
                pickedPhotosItem = nil
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
        .fullScreenCover(isPresented: $isFullScreen, onDismiss: {
            // 初回のプレイヤー終了(再生完了・手動クローズとも)でレビューを依頼
            guard !hasRequestedReview else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                // ペイウォール表示(履歴上限)と重なる場合は依頼しない
                guard !isPaywallPresented, !hasRequestedReview else { return }
                hasRequestedReview = true
                requestReview()
            }
        }) {
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
    func addVideoMenu<LabelContent: View>(@ViewBuilder label: () -> LabelContent) -> some View {
        Menu {
            Button {
                isImporterPresented = true
            } label: {
                Label("ファイルから", systemImage: "folder")
            }
            Button {
                isPhotosPickerPresented = true
            } label: {
                Label("写真から", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 4) {
            addVideoMenu {
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
