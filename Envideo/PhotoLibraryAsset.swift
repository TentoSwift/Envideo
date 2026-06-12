import UIKit
import AVFoundation
import Photos

/// PHAsset.localIdentifier から AVAsset / サムネイル / 表示名を解決するヘルパー
enum PhotoLibraryAsset {

    /// localIdentifier から PHAsset を取得
    static func asset(for identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject
    }

    /// 表示名(creationDate ベース)を作成
    static func displayName(for asset: PHAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = asset.creationDate {
            return formatter.string(from: date)
        }
        return String(localized: "Video")
    }

    /// PHAsset から AVAsset を非同期取得
    static func avAsset(for identifier: String) async -> AVAsset? {
        guard let phAsset = asset(for: identifier) else { return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: phAsset, options: options
            ) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    /// PHAsset からサムネイル(動画の先頭フレーム)を非同期取得
    static func thumbnail(for identifier: String, targetSize: CGSize) async -> UIImage? {
        guard let phAsset = asset(for: identifier) else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.resizeMode = .fast

        return await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // isDegraded == true の中間結果は無視して最終のみ通す
                if let info = info,
                   let degraded = info[PHImageResultIsDegradedKey] as? Bool,
                   degraded {
                    return
                }
                // ハンドラが複数回呼ばれても continuation の二重 resume(即クラッシュ)を防ぐ
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
