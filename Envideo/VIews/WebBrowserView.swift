import SwiftUI
import WebKit
import AVKit

// MARK: - Browser

struct WebBrowserView: View {
    @Binding var isPresented: Bool

    @State private var urlInput = "https://www.google.com"
    @State private var committedURL = URL(string: "https://www.google.com")!
    @State private var navigationID = UUID()
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef: WKWebView? = nil
    @State private var videoItem: VideoItem? = nil

    struct VideoItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        VStack(spacing: 0) {
            addressBar
                .padding()
                .background(.regularMaterial)

            WebViewRepresentable(
                url: committedURL,
                navigationID: navigationID,
                urlInput: $urlInput,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                onWebViewReady: { webViewRef = $0 },
                onVideoURL: { url in videoItem = VideoItem(url: url) }
            )
        }
        .fullScreenCover(item: $videoItem) { item in
            WebVideoPlayerView(url: item.url)
        }
    }

    @ViewBuilder
    private var addressBar: some View {
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

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("URLまたは検索ワードを入力", text: $urlInput)
                    .autocorrectionDisabled()
                    .onSubmit { navigate() }
                if isLoading { ProgressView().scaleEffect(0.75) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))

            Button {
                if isLoading { webViewRef?.stopLoading() }
                else { webViewRef?.reload() }
            } label: {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
    }

    private func navigate() {
        var str = urlInput.trimmingCharacters(in: .whitespaces)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            if str.contains(".") && !str.contains(" ") {
                str = "https://" + str
            } else {
                let q = str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
                str = "https://www.google.com/search?q=" + q
            }
        }
        if let url = URL(string: str) {
            committedURL = url
            navigationID = UUID()
        }
    }
}

// MARK: - WKWebView wrapper

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    let navigationID: UUID
    @Binding var urlInput: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    let onWebViewReady: (WKWebView) -> Void
    let onVideoURL: (URL) -> Void

    // JavaScript that intercepts <video> play events and forwards the src to Swift
    private static let videoInterceptJS = """
    (function() {
        function setup(v) {
            if (v._intercepted) return;
            v._intercepted = true;
            function handle() {
                var src = v.currentSrc || v.src;
                if (!src || src.startsWith('blob:') || src.startsWith('data:')) return;
                v.pause();
                window.webkit.messageHandlers.videoPlay.postMessage(src);
            }
            v.addEventListener('play', handle);
            if (!v.paused) handle();
        }
        function scan() { document.querySelectorAll('video').forEach(setup); }
        scan();
        new MutationObserver(scan).observe(document, { childList: true, subtree: true });
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(
            urlInput: $urlInput,
            isLoading: $isLoading,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            onVideoURL: onVideoURL
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(WeakMessageHandler(coordinator), name: "videoPlay")
        config.userContentController.addUserScript(
            WKUserScript(source: Self.videoInterceptJS,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: false)
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        coordinator.webView = webView
        coordinator.lastNavigationID = navigationID
        onWebViewReady(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastNavigationID != navigationID else { return }
        context.coordinator.lastNavigationID = navigationID
        webView.load(URLRequest(url: url))
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        @Binding var urlInput: String
        @Binding var isLoading: Bool
        @Binding var canGoBack: Bool
        @Binding var canGoForward: Bool
        let onVideoURL: (URL) -> Void
        weak var webView: WKWebView?
        var lastNavigationID: UUID? = nil

        private static let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "m3u8", "ts", "avi"]

        init(urlInput: Binding<String>, isLoading: Binding<Bool>,
             canGoBack: Binding<Bool>, canGoForward: Binding<Bool>,
             onVideoURL: @escaping (URL) -> Void) {
            _urlInput = urlInput
            _isLoading = isLoading
            _canGoBack = canGoBack
            _canGoForward = canGoForward
            self.onVideoURL = onVideoURL
        }

        // Called by JS when a video plays
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "videoPlay",
                  let urlString = message.body as? String,
                  let url = URL(string: urlString) else { return }
            DispatchQueue.main.async { self.onVideoURL(url) }
        }

        // Intercept direct video file navigation
        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url,
               Self.videoExts.contains(url.pathExtension.lowercased()) {
                DispatchQueue.main.async { self.onVideoURL(url) }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            isLoading = true; sync(webView)
        }
        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            isLoading = false; sync(webView)
        }
        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            isLoading = false; sync(webView)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            isLoading = false; sync(webView)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith _: WKWebViewConfiguration,
                     for action: WKNavigationAction,
                     windowFeatures _: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { webView.load(URLRequest(url: url)) }
            return nil
        }

        private func sync(_ webView: WKWebView) {
            urlInput = webView.url?.absoluteString ?? urlInput
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
        }
    }
}

// Breaks the retain cycle that WKUserContentController.add(_:name:) creates
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler & AnyObject)?
    init(_ target: any WKScriptMessageHandler & AnyObject) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

// MARK: - System player for web video

struct WebVideoPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        let player = AVPlayer(url: url)
        vc.player = player
        vc.showsPlaybackControls = true
        player.play()
        return vc
    }

    func updateUIViewController(_: AVPlayerViewController, context: Context) {}
}
