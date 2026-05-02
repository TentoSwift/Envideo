import SwiftUI
import UIKit
import WebKit

/// YouTube IFrame API ベースのプレイヤー (再生時間/位置を取得可能)
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let itemKey: String
    let initialPosition: Double
    let onProgress: (String, Double) -> Void
    let onDuration: (String, Double) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(key: itemKey, onProgress: onProgress, onDuration: onDuration, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(WeakHandler(context.coordinator), name: "youtubeBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false

        let html = makeHTML(videoID: videoID, initialPosition: initialPosition)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tento.File-Environment"
        webView.loadHTMLString(html, baseURL: URL(string: "https://\(bundleID)"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) { }

    private func makeHTML(videoID: String, initialPosition: Double) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                #wrapper {
                    position: fixed; top: 0; left: 0;
                    width: 100%; height: 100%;
                    overflow: hidden;
                }
                /* iframeを上に60px、左右に少しはみ出させてYouTubeのチロー(タイトル等)を隠す */
                #player, #player iframe {
                    position: absolute;
                    top: -60px; left: 0;
                    width: 100% !important;
                    height: calc(100% + 60px) !important;
                    border: 0;
                }
            </style>
        </head>
        <body>
            <div id="wrapper">
                <div id="player"></div>
            </div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                document.head.appendChild(tag);

                var player;
                var sentDuration = false;
                var triedFullscreen = false;
                var initialSeek = \(initialPosition);
                var timeReportInterval = null;

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(videoID)',
                        playerVars: {
                            autoplay: 1,
                            playsinline: 0,
                            rel: 0,
                            modestbranding: 1,
                            fs: 1,
                            start: Math.floor(initialSeek)
                        },
                        events: {
                            onReady: onPlayerReady,
                            onStateChange: onPlayerStateChange
                        }
                    });
                }

                function onPlayerReady(event) {
                    var d = event.target.getDuration();
                    if (d > 0 && !sentDuration) {
                        post('duration', d);
                        sentDuration = true;
                    }
                    if (initialSeek > 0) {
                        event.target.seekTo(initialSeek, true);
                    }
                    timeReportInterval = setInterval(reportTime, 1000);
                    requestFullscreen();
                }

                function requestFullscreen() {
                    if (triedFullscreen) return;
                    var iframe = document.querySelector('iframe');
                    if (!iframe) return;
                    var req = iframe.requestFullscreen ||
                              iframe.webkitRequestFullscreen ||
                              iframe.webkitEnterFullscreen;
                    if (req) {
                        try { req.call(iframe); triedFullscreen = true; } catch(e) {}
                    }
                }

                function onPlayerStateChange(event) {
                    if (!sentDuration) {
                        var d = player.getDuration();
                        if (d > 0) {
                            post('duration', d);
                            sentDuration = true;
                        }
                    }
                    if (event.data === YT.PlayerState.PLAYING) {
                        requestFullscreen();
                    }
                    if (event.data === YT.PlayerState.ENDED) {
                        // 時間ポーリングを停止して、終了通知を送る
                        if (timeReportInterval) {
                            clearInterval(timeReportInterval);
                            timeReportInterval = null;
                        }
                        post('ended', 0);
                    }
                }

                function reportTime() {
                    if (!player || !player.getCurrentTime) return;
                    var t = player.getCurrentTime();
                    if (t && t > 0) post('time', t);
                }

                function post(type, value) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtubeBridge) {
                        window.webkit.messageHandlers.youtubeBridge.postMessage({type: type, value: value});
                    }
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let key: String
        let onProgress: (String, Double) -> Void
        let onDuration: (String, Double) -> Void
        let onEnded: () -> Void
        private var sentDuration = false

        init(key: String,
             onProgress: @escaping (String, Double) -> Void,
             onDuration: @escaping (String, Double) -> Void,
             onEnded: @escaping () -> Void) {
            self.key = key
            self.onProgress = onProgress
            self.onDuration = onDuration
            self.onEnded = onEnded
        }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let value = body["value"] as? Double else { return }
            switch type {
            case "duration":
                if !sentDuration {
                    onDuration(key, value)
                    sentDuration = true
                }
            case "time":
                onProgress(key, value)
            case "ended":
                onEnded()
            default:
                break
            }
        }
    }

    // 弱参照で WKScriptMessageHandler の retain サイクル回避
    private final class WeakHandler: NSObject, WKScriptMessageHandler {
        weak var target: (any WKScriptMessageHandler & AnyObject)?
        init(_ target: any WKScriptMessageHandler & AnyObject) { self.target = target }
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            target?.userContentController(c, didReceive: m)
        }
    }
}
