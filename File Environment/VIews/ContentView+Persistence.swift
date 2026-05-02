import SwiftUI
import AVKit

extension ContentView {

    func generateThumbnail(for item: HistoryItem) {
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

    func addToHistoryAndSelect(_ pickedURL: URL) {
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

    func loadHistory() {
        videoHistory = loadHistoryItemsFromStorage()
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

    func saveHistoryItemsToStorage(_ items: [HistoryItem]) {
        let bookmarks = items.map { $0.bookmarkData }
        if let encoded = try? JSONEncoder().encode(bookmarks) {
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
