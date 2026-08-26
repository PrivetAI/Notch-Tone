import SwiftUI
import WebKit

/// The single web surface in Notch Tone. It serves both the launch panel and the
/// Privacy Policy sheet opened from Settings.
struct NTWebPanel: UIViewRepresentable {
    let ntAddress: String
    /// Fires once, as soon as the page starts rendering, so the caller can lift the
    /// loading screen overlay. Optional — the Settings/Privacy use site passes nothing.
    var onFirstPaint: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        private var fired = false

        // didCommit, NOT didFinish: on a heavy landing page didFinish arrives seconds
        // after the page is already visible and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { fire() }

        // A real failure must also lift the overlay, or the loading screen hangs forever.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is just an ordinary redirect — not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            fire()
        }

        private func fire() {
            guard !fired else { return }
            fired = true
            onFirstPaint?()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.onFirstPaint = onFirstPaint
        webView.navigationDelegate = context.coordinator
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

    // MUST NEVER reload: that would restart the page on every SwiftUI re-render.
    // Refreshing the callback is the only thing allowed here.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
    }
}
