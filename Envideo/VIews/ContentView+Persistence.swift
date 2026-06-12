import SwiftUI
import AVKit

extension ContentView {

    func generateThumbnail(for item: HistoryItem) {
        switch item.kind {
        case .youtube:
            generateYouTubeThumbnail(for: item)
        case .local:
            generateLocalThumbnail(for: item)
        }
    }

    private func generateLocalThumbnail(for item: HistoryItem) {
        guard let url = item.url else { return }
        let savedTime = max(0.5, positions[item.key] ?? 1)

        Task.detached {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)

            let timeValue = NSValue(time: CMTime(seconds: savedTime, preferredTimescale: 600))
            generator.generateCGImagesAsynchronously(forTimes: [timeValue]) { _, cgImage, _, result, error in
                guard result == .succeeded, let cgImage else {
                    if let error { print("Thumbnail failed:", error.localizedDescription) }
                    return
                }
                let image = Image(uiImage: UIImage(cgImage: cgImage))
                Task { @MainActor in
                    thumbnails[item.key] = image
                }
            }
        }
    }

    private func generateYouTubeThumbnail(for item: HistoryItem) {
        guard let videoID = item.youtubeID else { return }
        // 16:9のサムネイルを優先取得 (maxresdefault > sddefault > mqdefault)
        // 16:9 のみ。sddefault は 4:3+黒帯なので使わない
        let candidates = [
            "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg",  // 1280×720, HD動画のみ
            "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg",       // 320×180, 全動画にあり
        ]
        Task.detached {
            for urlString in candidates {
                guard let url = URL(string: urlString),
                      let (data, response) = try? await URLSession.shared.data(from: url),
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let uiImage = UIImage(data: data) else { continue }
                let image = Image(uiImage: uiImage)
                await MainActor.run {
                    thumbnails[item.key] = image
                }
                return
            }
        }
    }

    func addToHistoryAndSelect(_ pickedURL: URL) {
        Task {
            _ = pickedURL.startAccessingSecurityScopedResource()
            defer { pickedURL.stopAccessingSecurityScopedResource() }

            let bookmark = try pickedURL.bookmarkData()
            let name = pickedURL.deletingPathExtension().lastPathComponent
            let newItem = HistoryItem.local(bookmarkData: bookmark, displayName: name)
            await insertHistoryItem(newItem)
        }
    }

    /// YouTube動画を履歴に追加して再生開始
    /// titleはフォールバック。oEmbedで正式タイトルを取得できればそれを優先
    func addYouTubeVideo(videoID: String, title: String) {
        Task {
            let finalTitle = await fetchYouTubeTitle(videoID: videoID) ?? title
            let item = HistoryItem.youtube(videoID: videoID, title: finalTitle)
            await insertHistoryItem(item)
        }
    }

    /// YouTube oEmbed APIから動画タイトルを取得 (APIキー不要)
    private func fetchYouTubeTitle(videoID: String) async -> String? {
        let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                return title
            }
        } catch {
            // ネットワークエラー等。フォールバック側を使う
        }
        return nil
    }

    /// 共通: 履歴アイテム追加 + Paywall制限チェック + 選択
    @MainActor
    private func insertHistoryItem(_ newItem: HistoryItem) async {
        var items = loadHistoryItemsFromStorage()
        let isExisting = items.contains { $0.key == newItem.key }
        items.removeAll { $0.key == newItem.key }

        if !store.isPurchased && !isExisting && items.count >= StoreManager.historyLimit {
            if isFullScreen {
                playerController.player?.pause()
                playerController.player?.replaceCurrentItem(with: nil)
                isFullScreen = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isPaywallPresented = true
                }
            } else {
                isPaywallPresented = true
            }
            return
        }

        items.insert(newItem, at: 0)
        saveHistoryItemsToStorage(items)
        videoHistory = items
        selectedItem = newItem
    }

    func loadHistory() {
        var items = loadHistoryItemsFromStorage()
        if !store.isPurchased && items.count > StoreManager.historyLimit {
            items = Array(items.prefix(StoreManager.historyLimit))
            saveHistoryItemsToStorage(items)
        }
        videoHistory = items
    }

    func trimHistoryToLimit() {
        guard videoHistory.count > StoreManager.historyLimit else { return }
        let trimmed = Array(videoHistory.prefix(StoreManager.historyLimit))
        if let selected = selectedItem, !trimmed.contains(where: { $0.key == selected.key }) {
            playerController.player?.pause()
            playerController.player?.replaceCurrentItem(with: nil)
            isFullScreen = false
            selectedItem = nil
        }
        saveHistoryItemsToStorage(trimmed)
        videoHistory = trimmed
    }

    func deleteHistory(_ item: HistoryItem) {
        if selectedItem?.key == item.key {
            playerController.player?.pause()
            playerController.player?.replaceCurrentItem(with: nil)
            playerController.player = nil
            playerController.isPlaying = false
            playerController.currentTime = 0
            playerController.duration = 0
            selectedItem = nil
        }

        var items = loadHistoryItemsFromStorage()
        items.removeAll { $0.key == item.key }
        saveHistoryItemsToStorage(items)
        videoHistory = items
    }

    func loadHistoryItemsFromStorage() -> [HistoryItem] {
        // 新形式: [StoredHistoryItem]
        if let stored = try? JSONDecoder().decode([StoredHistoryItem].self, from: historyData) {
            return stored.compactMap { s in
                switch s.kind {
                case "youtube":
                    guard let yt = s.youtubeID else { return nil }
                    return HistoryItem.youtube(videoID: yt, title: s.displayName)
                default:
                    guard let data = s.bookmarkData else { return nil }
                    return HistoryItem.local(bookmarkData: data, displayName: s.displayName)
                }
            }
        }
        // 旧形式: [Data] (bookmarkだけ) — 後方互換
        if let bookmarks = try? JSONDecoder().decode([Data].self, from: historyData) {
            return bookmarks.map { d in
                var stale = false
                let url = try? URL(resolvingBookmarkData: d, bookmarkDataIsStale: &stale)
                let name = url?.deletingPathExtension().lastPathComponent ?? String(localized: "Video")
                return HistoryItem.local(bookmarkData: d, displayName: name)
            }
        }
        return []
    }

    func saveHistoryItemsToStorage(_ items: [HistoryItem]) {
        let stored = items.map { item in
            StoredHistoryItem(
                kind: item.kind.rawValue,
                bookmarkData: item.bookmarkData,
                youtubeID: item.youtubeID,
                displayName: item.displayName
            )
        }
        if let encoded = try? JSONEncoder().encode(stored) {
            historyData = encoded
        }
    }

    func loadPositions() {
        positions = (try? JSONDecoder().decode([String: Double].self, from: positionsData)) ?? [:]
    }

    func savePosition(key: String, seconds: Double) {
        positions[key] = seconds
        if let encoded = try? JSONEncoder().encode(positions) {
            positionsData = encoded
        }
    }

    func loadDurations() {
        durations = (try? JSONDecoder().decode([String: Double].self, from: durationsData)) ?? [:]
    }

    func saveDuration(key: String, seconds: Double) {
        durations[key] = seconds
        if let encoded = try? JSONEncoder().encode(durations) {
            durationsData = encoded
        }
    }

    func formatTime(_ seconds: Double) -> String {
        formatTimestamp(seconds)
    }
}
