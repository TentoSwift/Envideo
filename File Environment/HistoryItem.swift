import SwiftUI

extension Notification.Name {
    static let updateThumbnail = Notification.Name("updateThumbnail")
}

enum HistoryItemKind: String, Codable, Hashable {
    case local
    case youtube
}

struct HistoryItem: Identifiable, Hashable {
    let id: String
    let key: String
    let kind: HistoryItemKind
    let bookmarkData: Data?
    let youtubeID: String?
    let displayName: String
    let url: URL?

    private init(id: String, key: String, kind: HistoryItemKind,
                 bookmarkData: Data?, youtubeID: String?,
                 displayName: String, url: URL?) {
        self.id = id
        self.key = key
        self.kind = kind
        self.bookmarkData = bookmarkData
        self.youtubeID = youtubeID
        self.displayName = displayName
        self.url = url
    }

    /// ローカル動画(Document Picker由来) のファクトリ
    static func local(bookmarkData: Data, displayName: String) -> HistoryItem {
        let key = bookmarkData.base64EncodedString()
        var stale = false
        let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &stale)
        return HistoryItem(
            id: key, key: key, kind: .local,
            bookmarkData: bookmarkData, youtubeID: nil,
            displayName: displayName, url: url
        )
    }

    /// YouTube動画 のファクトリ
    static func youtube(videoID: String, title: String) -> HistoryItem {
        let key = "yt:\(videoID)"
        return HistoryItem(
            id: key, key: key, kind: .youtube,
            bookmarkData: nil, youtubeID: videoID,
            displayName: title, url: nil
        )
    }
}

/// 永続化用の中間モデル
struct StoredHistoryItem: Codable {
    let kind: String
    let bookmarkData: Data?
    let youtubeID: String?
    let displayName: String
}
