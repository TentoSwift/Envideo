import SwiftUI

/// Apple標準アプリ風のオンボーディング画面
struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // ヘッダー: アプリアイコン + タイトル
            VStack(spacing: 16) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                Text("ようこそ Envideo へ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 60)

            // 機能リスト
            VStack(alignment: .leading, spacing: 32) {
                OnboardingFeatureRow(
                    icon: "film.fill",
                    title: "動画ファイルを再生",
                    subtitle: "ローカルの動画ファイルを 高品質で再生"
                )
                OnboardingFeatureRow(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "YouTubeに対応",
                    subtitle: "URL貼り付けやブラウズで 動画を追加"
                )
                OnboardingFeatureRow(
                    icon: "theatermasks.fill",
                    title: "シネマ環境",
                    subtitle: "カスタム映画館でイマーシブ視聴"
                )
                OnboardingFeatureRow(
                    icon: "rectangle.center.inset.filled",
                    title: "座席を選んで視聴",
                    subtitle: "席を切り替えて好みの視点で楽しむ"
                )
            }
            .frame(maxWidth: 480, alignment: .leading)

            Spacer()

            // 続けるボタン
            Button {
                isPresented = false
            } label: {
                Text("続ける")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 480)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 60)
        .frame(width: 700, height: 820)
    }
}

// MARK: - 行コンポーネント

struct OnboardingFeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 50, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
