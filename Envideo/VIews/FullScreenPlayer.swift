import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Document picker helper

private final class DocumentPickerHelper: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL) -> Void
    init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick(url)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}

// MARK: - Up Next

struct UpNextView: View {
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let selectedKey: String?
    let onSelect: (HistoryItem) -> Void
    let onAddTapped: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                Button { onAddTapped() } label: {
                    AddVideoCard()
                }
                .buttonStyle(CustomButtonStyle())

                ForEach(videoHistory) { item in
                    Button { onSelect(item) } label: {
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

struct AddVideoCard: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.18))
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 38))
                Text("動画を追加")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: 290.4, height: 163.35)
        .cornerRadius(15)
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
            if let thumb { thumb.resizable().scaledToFill() }
            else { Rectangle().fill(.gray.opacity(0.3)) }
        }
        .frame(width: 290.4, height: 163.35)
        .clipped()
        .cornerRadius(15)
        .overlay(alignment: .bottomLeading) {
            VStack {
                HStack {
                    Text(item.displayName).lineLimit(1).fontWeight(.bold).font(.caption)
                    Spacer()
                    Text(formatDuration(total))
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.white)
                ProgressView(value: saved, total: max(total, 1)).tint(.white.opacity(0.8))
            }
            .padding(.horizontal, 10).padding(.bottom, 13).padding(.top)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 15,
                    bottomTrailingRadius: 15, topTrailingRadius: 0
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
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
        }
    }
}

// MARK: - Full-screen player

struct FullScreenPlayerView: UIViewControllerRepresentable {

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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            playerController: playerController,
            onProgress: onProgress,
            onDuration: onDuration,
            onAdd: onAdd,
            onEnded: onEnded
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = true
        context.coordinator.load(item: item, initialPosition: positions[item.key] ?? 0, into: vc)
        refreshUpNext(vc: vc, coordinator: context.coordinator)
        // イマーシブ環境のオープン/クローズに応じて座席タブを再構築
        context.coordinator.observeImmersiveState(vc: vc) { [self] in
            refreshUpNext(vc: vc, coordinator: context.coordinator)
        }
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        let coord = context.coordinator
        if coord.currentKey != item.key {
            coord.load(item: item, initialPosition: positions[item.key] ?? 0, into: vc)
        }
        refreshUpNext(vc: vc, coordinator: coord)
    }

    private func refreshUpNext(vc: AVPlayerViewController, coordinator: Coordinator) {
        let upNext = UpNextView(
            videoHistory: videoHistory, thumbnails: thumbnails,
            positions: positions, durations: durations,
            selectedKey: item.key, onSelect: onSelect,
            onAddTapped: { coordinator.presentFilePicker(from: vc) }
        )
        let inImmersive = CinemaState.shared.isImmersiveOpen
        let seatPicker = SeatPickerView()

        let upNextHC: UIHostingController<UpNextView>
        if let existing = vc.customInfoViewControllers.first as? UIHostingController<UpNextView> {
            upNextHC = existing
            upNextHC.rootView = upNext
        } else {
            upNextHC = UIHostingController(rootView: upNext)
            upNextHC.title = String(localized: "KEY_")
            upNextHC.preferredContentSize = CGSize(width: 900, height: 260)
        }

        var controllers: [UIViewController] = [upNextHC]
        if inImmersive {
            let seatHC: UIHostingController<SeatPickerView>
            if vc.customInfoViewControllers.count >= 2,
               let existingSeat = vc.customInfoViewControllers[1] as? UIHostingController<SeatPickerView> {
                seatHC = existingSeat
                seatHC.rootView = seatPicker
            } else {
                seatHC = UIHostingController(rootView: seatPicker)
                seatHC.title = String(localized: "座席")
                seatHC.preferredContentSize = CGSize(width: 900, height: 180)
            }
            controllers.append(seatHC)
        }
        vc.customInfoViewControllers = controllers
    }

    // MARK: - Coordinator

    final class Coordinator {
        let playerController: PlayerController
        let onProgress: (String, Double) -> Void
        let onDuration: (String, Double) -> Void
        let onAdd: (URL) -> Void
        let onEnded: (String) -> Void
        var currentKey: String?

        private weak var attachedPlayer: AVPlayer?
        private var observer: Any?
        private var statusObserver: NSKeyValueObservation?
        private var notificationToken: NSObjectProtocol?
        private var immersiveStateToken: NSObjectProtocol?
        private var scopedURL: URL?
        private var didStartAccess = false
        private var documentPickerHelper: DocumentPickerHelper?

        func observeImmersiveState(vc: AVPlayerViewController, onChange: @escaping () -> Void) {
            if let token = immersiveStateToken {
                NotificationCenter.default.removeObserver(token)
            }
            immersiveStateToken = NotificationCenter.default.addObserver(
                forName: .cinemaImmersiveStateChanged,
                object: nil, queue: .main
            ) { _ in onChange() }
        }

        init(playerController: PlayerController,
             onProgress: @escaping (String, Double) -> Void,
             onDuration: @escaping (String, Double) -> Void,
             onAdd: @escaping (URL) -> Void,
             onEnded: @escaping (String) -> Void) {
            self.playerController = playerController
            self.onProgress = onProgress
            self.onDuration = onDuration
            self.onAdd = onAdd
            self.onEnded = onEnded
        }

        func presentFilePicker(from vc: AVPlayerViewController) {
            let helper = DocumentPickerHelper { [weak self] url in
                self?.onAdd(url)
                self?.documentPickerHelper = nil
            }
            documentPickerHelper = helper
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
            picker.delegate = helper
            picker.allowsMultipleSelection = false
            vc.present(picker, animated: true)
        }

        func load(item: HistoryItem, initialPosition: Double, into vc: AVPlayerViewController) {
            tearDown()
            guard let url = item.url else { return }

            currentKey = item.key
            didStartAccess = url.startAccessingSecurityScopedResource()
            scopedURL = url

            let avItem = AVPlayerItem(url: url)
            let meta = AVMutableMetadataItem()
            meta.identifier = .commonIdentifierTitle
            meta.value = item.displayName as NSString
            meta.extendedLanguageTag = "und"
            avItem.externalMetadata = [meta]

            let player = AVPlayer(playerItem: avItem)
            vc.player = player

            if initialPosition > 0 {
                player.seek(to: CMTime(seconds: initialPosition, preferredTimescale: 600))
            }
            player.play()

            let ctrl = playerController
            DispatchQueue.main.async {
                ctrl.player = player
                ctrl.currentTime = 0
                ctrl.duration = 0
            }

            attach(player: player, avItem: avItem, key: item.key)
        }

        private func attach(player: AVPlayer, avItem: AVPlayerItem, key: String) {
            attachedPlayer = player

            statusObserver = player.observe(\.timeControlStatus) { [weak self] p, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch p.timeControlStatus {
                    case .playing: self.playerController.isPlaying = true
                    case .paused:  self.playerController.isPlaying = false
                    default: break
                    }
                }
            }

            observer = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self, let k = self.currentKey else { return }
                let s = CMTimeGetSeconds(time)
                if s.isFinite { self.onProgress(k, s); self.playerController.currentTime = s }
            }

            let dur = CMTimeGetSeconds(avItem.asset.duration)
            if dur.isFinite, dur > 0 { onDuration(key, dur); playerController.duration = dur }

            notificationToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: avItem, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                // ① まず周期的な時間観測を止める(これをやらないと0で保存しても上書きされる)
                if let p = self.attachedPlayer, let obs = self.observer {
                    p.removeTimeObserver(obs)
                    self.observer = nil
                }
                // ② 動画を最初に戻して停止
                self.attachedPlayer?.seek(to: .zero)
                self.playerController.currentTime = 0
                self.playerController.isPlaying = false
                // ③ 位置0を保存(サムネ更新より先に。サムネは positions[key] を読むため)
                if let key = self.currentKey {
                    self.onProgress(key, 0)
                }
                // ④ サムネ更新通知 (positions[key]=0で再生成される)
                NotificationCenter.default.post(name: .updateThumbnail, object: nil)
                // ⑤ フルスクリーン閉じる
                if let key = self.currentKey {
                    self.onEnded(key)
                }
            }
        }

        func tearDown() {
            attachedPlayer?.pause()
            if let p = attachedPlayer, let obs = observer { p.removeTimeObserver(obs) }
            notificationToken.map { NotificationCenter.default.removeObserver($0) }
            immersiveStateToken.map { NotificationCenter.default.removeObserver($0) }
            statusObserver?.invalidate()
            observer = nil; notificationToken = nil; immersiveStateToken = nil
            statusObserver = nil; attachedPlayer = nil
            if didStartAccess, let url = scopedURL { url.stopAccessingSecurityScopedResource() }
            scopedURL = nil; didStartAccess = false
        }

        deinit {
            tearDown()
            let ctrl = playerController
            DispatchQueue.main.async {
                ctrl.player = nil
                ctrl.isPlaying = false
                ctrl.currentTime = 0
                ctrl.duration = 0
            }
        }
    }
}
