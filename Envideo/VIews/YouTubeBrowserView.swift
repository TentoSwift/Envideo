import SwiftUI
import UIKit
import WebKit

/// YouTube サイトをブラウズして動画を選択 → 履歴に追加
struct YouTubeBrowserView: View {
    @Binding var isPresented: Bool
    let onAdd: (_ videoID: String, _ title: String) -> Void

    @State private var currentURL: URL? = URL(string: "https://www.youtube.com")
    @State private var pageTitle: String = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef: WKWebView? = nil
    @State private var didAutoTrigger = false

    private var detectedVideoID: String? {
        guard let url = currentURL else { return nil }
        return YouTubeURL.extractID(from: url.absoluteString)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").fontWeight(.semibold)
                }
                .buttonStyle(.plain)

                Button { webViewRef?.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button { webViewRef?.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)

                Text(currentURL?.absoluteString ?? "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(.regularMaterial)

            YouTubeBrowserWebView(
                initialURL: URL(string: "https://www.youtube.com")!,
                currentURL: $currentURL,
                pageTitle: $pageTitle,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                onWebViewReady: { webViewRef = $0 }
            )
        }
        .onChange(of: detectedVideoID) { _, newID in
            // 動画ページに遷移したら自動で追加・閉じる・再生
            guard let videoID = newID, !didAutoTrigger else { return }
            didAutoTrigger = true
            // タイトル取得まで少し待つ (0.8秒)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let title = cleanedTitle(from: pageTitle)
                onAdd(videoID, title)
                isPresented = false
            }
        }
    }

    private func cleanedTitle(from raw: String) -> String {
        // YouTubeのタイトルは "動画名 - YouTube" 形式なので " - YouTube" を除去
        var t = raw
        if t.hasSuffix(" - YouTube") { t.removeLast(" - YouTube".count) }
        return t.isEmpty ? "YouTube動画" : t
    }
}

// MARK: - WKWebView wrapper

struct YouTubeBrowserWebView: UIViewRepresentable {
    let initialURL: URL
    @Binding var currentURL: URL?
    @Binding var pageTitle: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    let onWebViewReady: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(currentURL: $currentURL,
                    pageTitle: $pageTitle,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        onWebViewReady(webView)

        // モバイル版ではなくデスクトップ版を表示
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // YouTube は SPA なので URL の変化を KVO で監視
        context.coordinator.urlObservation = webView.observe(\.url, options: [.new]) { [weak coord = context.coordinator] webView, _ in
            DispatchQueue.main.async {
                coord?.currentURL = webView.url
                // タイトル更新
                webView.evaluateJavaScript("document.title") { result, _ in
                    if let title = result as? String {
                        DispatchQueue.main.async { coord?.pageTitle = title }
                    }
                }
            }
        }

        webView.load(URLRequest(url: initialURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) { }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var currentURL: URL?
        @Binding var pageTitle: String
        @Binding var canGoBack: Bool
        @Binding var canGoForward: Bool
        weak var webView: WKWebView?
        var urlObservation: NSKeyValueObservation?

        init(currentURL: Binding<URL?>, pageTitle: Binding<String>,
             canGoBack: Binding<Bool>, canGoForward: Binding<Bool>) {
            _currentURL = currentURL
            _pageTitle = pageTitle
            _canGoBack = canGoBack
            _canGoForward = canGoForward
        }

        deinit {
            urlObservation?.invalidate()
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            sync(webView)
            // タイトル取得
            webView.evaluateJavaScript("document.title") { [weak self] result, _ in
                if let title = result as? String {
                    DispatchQueue.main.async { self?.pageTitle = title }
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
            sync(webView)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        private func sync(_ webView: WKWebView) {
            currentURL = webView.url
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
        }
    }
}
