import SwiftUI
import WebKit

/// The single web surface in Notch Tone. It serves both the launch panel and the
/// Privacy Policy sheet opened from Settings.
struct NTWebPanel: UIViewRepresentable {
    let ntAddress: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        // Keeps scrollable content clear of the home indicator once the frame extends
        // past the bottom safe area. Never .never.
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // The presenting branch runs in the dark scheme so the status bar glyphs stay
        // white. Pin the page itself back to light.
        webView.overrideUserInterfaceStyle = .light
        if let url = URL(string: ntAddress) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // Must stay empty: reloading here would restart the page on every SwiftUI re-render.
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
