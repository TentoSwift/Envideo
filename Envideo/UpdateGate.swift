import SwiftUI

/// 強制アップデート判定。
/// GitHub Pages 上の静的 JSON ({"minimumBuild": N}) を起動時に取得し、
/// 現在のビルド番号が minimumBuild 未満なら updateRequired を true にする。
///
/// フェイルオープン: 取得に成功したときだけ判定する。通信失敗・解析失敗時は
/// updateRequired を変更しない(= 決してブロックしない)。通信障害でアプリが
/// 使えなくなる事故を防ぐため。
@MainActor
@Observable
final class UpdateChecker {
    var updateRequired = false

    let appStoreURL = URL(string: "https://apps.apple.com/app/id6779471160")!
    private let configURL = URL(string: "https://tentoswift.github.io/privacy-policies/envideo-version.json")!

    func check() async {
        guard let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let currentBuild = Int(buildString) else { return }
        do {
            var request = URLRequest(url: configURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            let config = try JSONDecoder().decode(VersionConfig.self, from: data)
            updateRequired = currentBuild < config.minimumBuild
        } catch {
            // 取得失敗時はブロックしない
        }
    }

    private struct VersionConfig: Decodable {
        let minimumBuild: Int
    }
}

/// 強制アップデート時に全画面で表示するブロック画面。
/// これ以外の UI は描画されないため、操作を完全に塞ぐ。
struct UpdateRequiredView: View {
    let appStoreURL: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("アップデートが必要です")
                .font(.title)
                .fontWeight(.bold)

            Text("最新バージョンに更新してからご利用ください。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                openURL(appStoreURL)
            } label: {
                Text("App Store でアップデート")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
