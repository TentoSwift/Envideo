import SwiftUI

extension Notification.Name {
    static let updateThumbnail = Notification.Name("updateThumbnail")
}

enum HistoryItemKind: String, Codable, Hashable {
    case local
    case youtube
    case photoLibrary
}

struct HistoryItem: Identifiable, Hashable {
    let id: String
    let key: String
    let kind: HistoryItemKind
    let bookmarkData: Data?
    let youtubeID: String?
    let photoAssetID: String?
    let displayName: String
    let url: URL?

    private init(id: String, key: String, kind: HistoryItemKind,
                 bookmarkData: Data?, youtubeID: String?,
                 photoAssetID: String?,
                 displayName: String, url: URL?) {
        self.id = id
        self.key = key
        self.kind = kind
        self.bookmarkData = bookmarkData
        self.youtubeID = youtubeID
        self.photoAssetID = photoAssetID
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
            photoAssetID: nil,
            displayName: displayName, url: url
        )
    }

    /// YouTube動画 のファクトリ
    static func youtube(videoID: String, title: String) -> HistoryItem {
        let key = "yt:\(videoID)"
        return HistoryItem(
            id: key, key: key, kind: .youtube,
            bookmarkData: nil, youtubeID: videoID,
            photoAssetID: nil,
            displayName: title, url: nil
        )
    }

    /// 写真ライブラリ動画(PHAsset.localIdentifier 由来) のファクトリ
    static func photoLibrary(assetID: String, displayName: String) -> HistoryItem {
        let key = "ph:\(assetID)"
        return HistoryItem(
            id: key, key: key, kind: .photoLibrary,
            bookmarkData: nil, youtubeID: nil,
            photoAssetID: assetID,
            displayName: displayName, url: nil
        )
    }
}

/// 永続化用の中間モデル
struct StoredHistoryItem: Codable {
    let kind: String
    let bookmarkData: Data?
    let youtubeID: String?
    let photoAssetID: String?
    let displayName: String
}
