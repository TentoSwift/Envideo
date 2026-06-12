import SwiftUI

/// YouTube URL からビデオIDを抽出するユーティリティ
enum YouTubeURL {
    /// 対応形式:
    ///  - https://www.youtube.com/watch?v=XXXXXXXXXXX
    ///  - https://youtu.be/XXXXXXXXXXX
    ///  - https://www.youtube.com/shorts/XXXXXXXXXXX
    ///  - https://www.youtube.com/embed/XXXXXXXXXXX
    ///  - 直接のID (11桁)
    static func extractID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidID(trimmed) { return trimmed }

        guard let url = URL(string: trimmed),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // youtu.be/<id>
        if let host = comps.host, host.contains("youtu.be") {
            let id = String(comps.path.dropFirst())
            return isValidID(id) ? id : nil
        }

        // youtube.com/watch?v=<id>
        if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value,
           isValidID(v) {
            return v
        }

        // youtube.com/shorts/<id> or /embed/<id>
        let pathComponents = comps.path.split(separator: "/")
        if pathComponents.count >= 2,
           ["shorts", "embed", "v"].contains(String(pathComponents[0])) {
            let id = String(pathComponents[1])
            return isValidID(id) ? id : nil
        }

        return nil
    }

    private static func isValidID(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
}

/// YouTube URL を貼り付けて履歴に追加するシート
struct YouTubeAddView: View {
    @Binding var isPresented: Bool
    let onAdd: (_ videoID: String, _ title: String) -> Void

    @State private var input: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("YouTube URLを貼り付け")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("youtube.com / youtu.be のリンクをサポート")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("https://www.youtube.com/watch?v=...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .onSubmit { tryAdd() }

                if let error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                Button {
                    tryAdd()
                } label: {
                    Text("追加")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.isEmpty)
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
            .navigationTitle("YouTubeを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { isPresented = false }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    private func tryAdd() {
        guard let id = YouTubeURL.extractID(from: input) else {
            error = "URLからYouTube動画IDを取得できませんでした"
            return
        }
        // タイトルは取得できないのでIDから仮の名前を付ける(後でAPI拡張可能)
        let title = "YouTube — \(id)"
        onAdd(id, title)
        isPresented = false
    }
}
