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

struct UpNextView: View {
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let selectedKey: String?
    let onSelect: (HistoryItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(videoHistory) { item in
                    Button{
                        onSelect(item)
                    } label: {
                        UpNextCardView(
                            item: item,
                            thumb: thumbnails[item.key],
                            saved: positions[item.key] ?? 0,
                            total: durations[item.key] ?? 0,
                            isSelected: selectedKey == item.key
                        )
                    }
                    .buttonStyle(CustomButtonStyle())
                    
                    
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20)
        .scrollTargetBehavior(.viewAligned)
        .scrollInputBehavior(.enabled, for: .look)
    }
}

struct UpNextCardView: View {
    let item: HistoryItem
    let thumb: Image?
    let saved: Double
    let total: Double
    let isSelected: Bool

    var body: some View {
        Group {
            if let thumb {
                thumb.resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.3))
            }
        }
        .frame(width: 290.4, height: 163.35)
        .clipped()
            .cornerRadius(15)
            .overlay(alignment: .bottomLeading) {
                VStack {
                    HStack {
                        Text(item.displayName)
                            .lineLimit(1)
                            .fontWeight(.bold)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(total / 60))")
                            .font(.system(.caption, design: .rounded))
                        +
                        Text("分")
                            .font(.caption)
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
                                .init(color: .clear, location: 0.0), // 一番上は透明
                                .init(color: .black.opacity(0.8), location: 0.5), // 上から40%の位置で完全にすりガラスになる
                                .init(color: .black, location: 0.6),
                                .init(color: .white, location: 1.0)  // 下までずっとすりガラスをキープ
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
    }
}

extension Notification.Name {
    static let updateThumbnail = Notification.Name("updateThumbnail")
}

struct FullScreenPlayerView: UIViewControllerRepresentable {

    let player: AVPlayer
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let selectedKey: String?
    let onSelect: (HistoryItem) -> Void

    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        // 初期プレイヤーのセット
        vc.player = player
        vc.showsPlaybackControls = true

        // Up Next View の作成
        let view = UpNextView(
            videoHistory: videoHistory,
            thumbnails: thumbnails,
            positions: positions,
            durations: durations,
            selectedKey: selectedKey,
            onSelect: onSelect
        )

        let hc = UIHostingController(rootView: view)
        hc.title = String(localized: "KEY_")
        hc.preferredContentSize = CGSize(width: 900, height: 260)

        vc.customInfoViewControllers = [hc]
        return vc
    }

    // --- ここが重要 ---
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        // 1. プレイヤーの差し替え
        if vc.player !== player {
            vc.player?.pause()
            vc.player = player
            
            // 保存された再生位置を取得（selectedKey を使って positions から探す）
            let savedPosition = positions[selectedKey ?? ""] ?? 0
            
            // 履歴（保存位置）が 0 の時だけ 0.1秒に、それ以外は保存位置へ
            let targetSeconds = (savedPosition > 0) ? savedPosition : 0.1
            let startTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            
            // シークを実行
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    DispatchQueue.main.async {
                        player.play()
                    }
                }
            }
        }
        
        // 2. Up Next View の更新
        if let hc = vc.customInfoViewControllers.first as? UIHostingController<UpNextView> {
            hc.rootView = UpNextView(
                videoHistory: videoHistory,
                thumbnails: thumbnails,
                positions: positions,
                durations: durations,
                selectedKey: selectedKey,
                onSelect: onSelect
            )
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var playerController = PlayerController()
    @AppStorage("videoHistoryBookmarks") private var historyData: Data = Data()
    @AppStorage("videoPositionsByBookmarkKey") private var positionsData: Data = Data()
    @AppStorage("videoDurationsByBookmarkKey") private var durationsData: Data = Data()

    @State private var thumbnails: [String: Image] = [:]
    @State private var videoHistory: [HistoryItem] = []
    @State private var positions: [String: Double] = [:]
    @State private var durations: [String: Double] = [:]

    @State private var selectedItem: HistoryItem? = nil
    @State private var isImporterPresented = false
    @State private var aspectRatio: CGFloat = 9/16
    @State private var isFullScreen = false
    
    @State private var isDisplayHistory: Bool = false

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {

                // Player
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
                            withAnimation {
                                isDisplayHistory = false
                            }
                        }
                    )
                } else {
                    List {
                        Section("再生履歴") {
                            ForEach(videoHistory) { item in
                                historyRow(item)
                            }
                        }
                    }
                }

                // History List
                if videoHistory.isEmpty {
                    Text("履歴がありません")
                        .foregroundStyle(.secondary)
                    Button("追加") {
                        isImporterPresented.toggle()
                    }
                }
            }
            .ignoresSafeArea()
            .ornament(
                visibility: .hidden,
                attachmentAnchor: .scene(.trailing)
            ) {
                List {
                    Section {
                        ForEach(videoHistory) { item in
                            historyRow(item)
                        }
                        Button("追加", systemImage: "plus") {
                            isImporterPresented.toggle()
                        }
                    }
                }
                .contentMargins(.top, 40)
                .contentMargins(.bottom, 40)
                .listStyle(.plain)
                .frame(width: 350, height: 500)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .ornament(
                visibility: .visible,
                attachmentAnchor: .scene(.bottom)
            ) {
                VStack(alignment: .center) {
                    HStack {
                        if let item = selectedItem {
                            HStack {
                                Button {
                                    playerController.skip(by: -15)
                                } label: {
                                    Label("15秒戻す", systemImage: "gobackward.15")
                                        .labelStyle(.iconOnly)
                                        .font(.system(size: 28))
                                        .fontWeight(.semibold)
                                        .padding()
                                }
                                .buttonStyle(.plain)
                                Button {
                                    playerController.toggle()
                                } label: {
                                    Label(playerController.isPlaying ? "停止" : "再生", systemImage: playerController.isPlaying ? "pause.fill" : "play.fill")
                                        .contentTransition(.symbolEffect(.replace))
                                        .labelStyle(.iconOnly)
                                        .font(.system(size: 40))
                                        .fontWeight(.semibold)
                                        .padding()
                                }
                                .buttonStyle(.plain)
                                Button {
                                    playerController.skip(by: 15)
                                } label: {
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
                                            if !editing {
                                                playerController.seek(to: playerController.currentTime)
                                            }
                                        }
                                    )
                                    .tint(.gray.mix(with: .white, by: 0.9).opacity(0.8))
                                    .frame(maxWidth: .infinity, maxHeight: 10)
                                }
                                Spacer()
                            }
                            .padding(.trailing)
                            .padding(.bottom)
                            Button {
                                isFullScreen = true
                            } label: {
                                Label("全画面", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 30))
                                    .fontWeight(.semibold)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                            Button {
                                withAnimation {
                                    isImporterPresented.toggle()
                                }
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
                                withAnimation {
                                    isDisplayHistory.toggle()
                                }
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
                            }
                            .buttonStyle(.plain)
                            
                        } else {
                            Spacer()
                                .frame(height: 70)
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
                            // 各カードをスクロールターゲットとして登録
                            .scrollTargetLayout()
                        }
                        .scrollInputBehavior(.enabled, for: .look)
                        // 「カード単位」で止める
                        .contentMargins(.horizontal, 20)
                        .frame(width: 1000)
                        .frame(height: 250)
                        .scrollIndicators(.hidden)
                        .glassBackgroundEffect()
                        .scrollTargetBehavior(.viewAligned)
                    }
                }
              
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
                switch result {
                case .success(let urls):
                    guard let pickedURL = urls.first else { return }
                    addToHistoryAndSelect(pickedURL)
                    
                case .failure(let error):
                    print("Import failed:", error.localizedDescription)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                isDisplayHistory = false
            }
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

    // MARK: - History Row
    private func playFromBeginning(_ item: HistoryItem) {
        // まず保存済み位置を0に更新（次にVCを作るときの初期位置になる）
        savePosition(key: item.key, seconds: 0)

        // すでに選択中の動画なら、その場で先頭に戻して再生
        if selectedItem?.key == item.key {
            playerController.seek(to: 0)
            playerController.play()
            return
        }

        // 選択中でない動画なら、選択を切り替えて先頭から再生
        selectedItem = item

        // 新しいAVPlayerがセットされるのは次の描画サイクルなので、
        // 念のためメインキューで先頭再生を保証する
        DispatchQueue.main.async {
            self.playerController.seek(to: 0)
            self.playerController.play()
        }
    }
    @ViewBuilder
    private func historyRow1(_ item: HistoryItem) -> some View {
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
                        // 再生中マーク
                        if selectedItem?.key == item.key {
                            Image("apple.nowplaying")
                                .foregroundStyle(.white)
                                .font(.system(size: 50))
                                .opacity(selectedItem?.key == item.key ? 0.7 : 0)
                            
                        }
                    }
                    .background(
                        Rectangle()
                            .fill(.clear)
                    )
                    .overlay(alignment: .bottomLeading) {
                        if let total = durations[item.key], total > 0 {
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
                                        Text("\(Int(total / 60))")
                                            .font(.system(.caption, design: .rounded))
                                        +
                                        Text("分")
                                            .font(.caption)
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
                                            // locationは 0.0(上端) 〜 1.0(下端) で指定します
                                            .init(color: .clear, location: 0.0), // 一番上は透明
                                            .init(color: .black.opacity(0.8), location: 0.5), // 上から40%の位置で完全にすりガラスになる
                                            .init(color: .black, location: 0.6),
                                            .init(color: .white, location: 1.0)  // 下までずっとすりガラスをキープ
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            }
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
                .overlay{
                    if selectedItem?.key == item.key {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.thickMaterial.opacity(0.7))
                    }
                }
                .overlay(alignment: .center) {
                    // 再生中マーク
                    if selectedItem?.key == item.key {
                        Image("apple.nowplaying")
                            .foregroundStyle(.white)
                            .font(.system(size: 50))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let total = durations[item.key], total > 0 {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(formatTime(saved)) / \(formatTime(total))")
                                Spacer()
                                Text(item.displayName)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            ProgressView(value: saved, total: total)
                                .tint(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 13)
                        .padding(.top, 5)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 15,
                                bottomTrailingRadius: 15,
                                topTrailingRadius: 0
                            )
                                .fill(.ultraThickMaterial)
                        )
                    }
                }
                .onTapGesture {
                    selectedItem = item
                }
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
    private func historyRow(_ item: HistoryItem) -> some View {
        let saved = positions[item.key] ?? 0

        Button {
            selectedItem = item
        } label: {
            HStack(spacing: 10) {

                if let thumb = thumbnails[item.key] {
                    thumb
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 45)
                        .clipped()
                        .cornerRadius(6)
                        .overlay {
                            if selectedItem?.key == item.key {
                                Rectangle()
                                    .fill(.thickMaterial.opacity(0.1))
                            }
                        }
                        .overlay(alignment: .center) {
                            // 再生中マーク
                            if selectedItem?.key == item.key {
                                Image("apple.nowplaying")
                                    .foregroundStyle(.white)
                            }
                        }
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 80, height: 45)
                        .cornerRadius(6)
                        .onAppear {
                            if thumbnails[item.key] == nil {
                                generateThumbnail(for: item)
                            }
                        }
                        .overlay{
                            if selectedItem?.key == item.key {
                                Rectangle()
                                    .fill(.thickMaterial.opacity(0.1))
                            }
                        }
                        .overlay(alignment: .center) {
                            // 再生中マーク
                            if selectedItem?.key == item.key {
                                Image("apple.nowplaying")
                                    .foregroundStyle(.white)
                            }
                        }
                }

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
}

// MARK: - HistoryItem

struct HistoryItem: Identifiable, Hashable {
    let id: String
    let key: String
    let bookmarkData: Data
    let displayName: String
    let url: URL?

    init(id: String, key: String, bookmarkData: Data, displayName: String) {
        self.id = id
        self.key = key
        self.bookmarkData = bookmarkData
        self.displayName = displayName
        var stale = false
        self.url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &stale)
    }
}

// MARK: - Persistence

extension ContentView {

    private func generateThumbnail(for item: HistoryItem) {
        guard let url = item.url else { return }

        let savedTime = max(0.5, positions[item.key] ?? 1)

        Task.detached {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)

            let cmTime = CMTime(seconds: savedTime, preferredTimescale: 600)
            let timeValue = NSValue(time: cmTime)

            generator.generateCGImagesAsynchronously(forTimes: [timeValue]) { _, cgImage, _, result, error in

                guard result == .succeeded,
                      let cgImage else {
                    if let error {
                        print("Thumbnail failed:", error.localizedDescription)
                    }
                    return
                }

                let uiImage = UIImage(cgImage: cgImage)
                let image = Image(uiImage: uiImage)

                Task { @MainActor in
                    thumbnails[item.key] = image
                }
            }
        }
    }

    private func addToHistoryAndSelect(_ pickedURL: URL) {
        Task {
            _ = pickedURL.startAccessingSecurityScopedResource()
            defer { pickedURL.stopAccessingSecurityScopedResource() }

            let bookmark = try pickedURL.bookmarkData()
            let key = bookmark.base64EncodedString()
            let name = pickedURL.deletingPathExtension().lastPathComponent

            var items = loadHistoryItemsFromStorage()
            items.removeAll { $0.key == key }
            let newItem = HistoryItem(id: key, key: key, bookmarkData: bookmark, displayName: name)
            items.insert(newItem, at: 0)

            saveHistoryItemsToStorage(items)

            await MainActor.run {
                videoHistory = items
                selectedItem = newItem
            }
        }
    }

    private func loadHistory() {
        videoHistory = loadHistoryItemsFromStorage()
    }

    private func deleteHistory(_ item: HistoryItem) {

        // 再生中の動画を削除する場合
        if selectedItem?.key == item.key {

            // 再生停止
            playerController.player?.pause()

            // observer停止
            playerController.player?.replaceCurrentItem(with: nil)

            // プレイヤー破棄
            playerController.player = nil
            playerController.isPlaying = false
            playerController.currentTime = 0
            playerController.duration = 1

            // 選択解除
            selectedItem = nil
        }

        // 履歴削除
        var items = loadHistoryItemsFromStorage()
        items.removeAll { $0.key == item.key }
        saveHistoryItemsToStorage(items)
        videoHistory = items
    }

    private func loadHistoryItemsFromStorage() -> [HistoryItem] {
        guard let bookmarks = try? JSONDecoder().decode([Data].self, from: historyData)
        else { return [] }

        return bookmarks.map {
            let key = $0.base64EncodedString()
            var stale = false
            let url = try? URL(resolvingBookmarkData: $0, bookmarkDataIsStale: &stale)
            let name = url?.deletingPathExtension().lastPathComponent ?? "Video"
            return HistoryItem(id: key, key: key, bookmarkData: $0, displayName: name)
        }
    }

    private func saveHistoryItemsToStorage(_ items: [HistoryItem]) {
        let bookmarks = items.map { $0.bookmarkData }
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            historyData = encoded
        }
    }

    private func loadPositions() {
        positions = (try? JSONDecoder().decode([String: Double].self, from: positionsData)) ?? [:]
    }

    private func savePosition(key: String, seconds: Double) {
        positions[key] = seconds
        if let encoded = try? JSONEncoder().encode(positions) {
            positionsData = encoded
        }
    }

    private func loadDurations() {
        durations = (try? JSONDecoder().decode([String: Double].self, from: durationsData)) ?? [:]
    }

    private func saveDuration(key: String, seconds: Double) {
        durations[key] = seconds
        if let encoded = try? JSONEncoder().encode(durations) {
            durationsData = encoded
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        formatTimestamp(seconds)
    }
}

// MARK: - PlayerContainerView
