import SwiftUI
import WebKit

// MARK: - Surviving a cold start
//
// Two things lose a signed-in session when the app is swiped out of the switcher, and
// neither is fixed by the data store being persistent — it already is:
//
//   1. The panel reloads the TRACKER link on every launch, so a registered user
//      re-enters the funnel at the landing page instead of the page they were on.
//      `NTPanelSession` remembers where they actually were.
//   2. A session cookie — one with no expiry, the plain PHPSESSID case — lives in the
//      WebKit networking process and dies with it. Nothing is written to disk, so the
//      persistent store does not help. `NTPanelCookies` mirrors the jar out and
//      re-injects it with an explicit expiry, and that is what keeps the login alive.

/// Remembers the last page the panel was really on, so a cold start resumes there
/// instead of re-running the redirect chain from the top.
enum NTPanelSession {
    private static let addressKey = "nt.panel.resume.address"
    private static let stampKey   = "nt.panel.resume.stamp"
    /// Past this a resumed address is likelier to be stale than useful.
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 30

    static func remember(_ url: URL?, trackerHost: String) {
        // No tracker host means this is not the launch panel — the Settings/Privacy sheet
        // passes none. It must never write a resume address, or the next launch would open
        // the privacy page instead of the offer.
        guard !trackerHost.isEmpty else { return }
        guard let url = url, url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        // Never store our own hop: resuming it would re-run the very chain this avoids.
        if host == trackerHost || host.hasSuffix("." + trackerHost) { return }
        let defaults = UserDefaults.standard
        defaults.set(url.absoluteString, forKey: addressKey)
        defaults.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    static func resumeAddress() -> String? {
        let defaults = UserDefaults.standard
        guard let address = defaults.string(forKey: addressKey),
              let url = URL(string: address), url.host != nil else { return nil }
        let stamp = defaults.double(forKey: stampKey)
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < maxAge else { return nil }
        return address
    }

    static func forget() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: addressKey)
        defaults.removeObject(forKey: stampKey)
    }
}

/// Mirrors the WebKit cookie jar out to `UserDefaults` and back.
///
/// The default data store already persists cookies that carry an expiry. What it does
/// not persist is a session cookie — and a session cookie is what most sign-ins hand
/// out — so the mirror stamps an explicit expiry on the way out.
enum NTPanelCookies {
    private static let key = "nt.panel.cookies"
    /// Expiry given to a cookie that had none. Long enough to outlive ordinary use.
    private static let sessionLifetime: TimeInterval = 60 * 60 * 24 * 180
    /// WebKit has been seen to swallow a `setCookie` completion. Never let that hold a
    /// launch: past this the page loads regardless.
    private static let restoreGrace: TimeInterval = 1.5

    static func snapshot() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let payload: [[String: String]] = cookies.map { cookie in
                let expiry = cookie.expiresDate ?? Date().addingTimeInterval(sessionLifetime)
                return [
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain,
                    "path": cookie.path.isEmpty ? "/" : cookie.path,
                    "secure": cookie.isSecure ? "1" : "0",
                    "expires": String(expiry.timeIntervalSince1970)
                ]
            }
            // Wholesale overwrite, so a sign-out that empties the jar empties the mirror
            // too and cannot resurrect a dead session on the next launch.
            UserDefaults.standard.set(payload, forKey: key)
        }
    }

    /// Re-injects the mirror and then calls back. The caller MUST wait for this before
    /// the first load: a request that goes out early is the one that arrives signed out.
    static func restore(completion: @escaping () -> Void) {
        guard let payload = UserDefaults.standard.array(forKey: key) as? [[String: String]],
              !payload.isEmpty else { completion(); return }

        let store = WKWebsiteDataStore.default().httpCookieStore
        let now = Date()
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            completion()
        }

        let group = DispatchGroup()
        var queued = 0
        for entry in payload {
            guard let name = entry["name"], let value = entry["value"],
                  let domain = entry["domain"], let path = entry["path"],
                  let raw = entry["expires"], let seconds = TimeInterval(raw) else { continue }
            let expiry = Date(timeIntervalSince1970: seconds)
            guard expiry > now else { continue }
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name, .value: value, .domain: domain, .path: path, .expires: expiry
            ]
            if entry["secure"] == "1" { props[.secure] = "TRUE" }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            queued += 1
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }

        guard queued > 0 else { finish(); return }
        group.notify(queue: .main) { finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreGrace) { finish() }
    }
}

/// The single web surface in Notch Tone. It serves both the launch panel and the
/// Privacy Policy sheet opened from Settings.
struct NTWebPanel: UIViewRepresentable {
    let ntAddress: String
    /// Our own host — the tracker hop, which must never be remembered as a resume point.
    /// The Settings/Privacy sheet passes none, which also switches remembering off.
    var trackerHost: String = ""
    /// Where to go if `ntAddress` is a resumed address that no longer loads. nil when the
    /// panel already started at the tracker link.
    var fallbackAddress: String? = nil
    /// Fires once, as soon as the page starts rendering, so the caller can lift the
    /// loading screen overlay. Optional — the Settings/Privacy use site passes nothing.
    var onFirstPaint: (() -> Void)? = nil
    /// Fires when nothing loads at all — live or cached. The caller shows the native app.
    var onDeadEnd: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        var onDeadEnd: (() -> Void)?
        var trackerHost = ""
        var fallbackAddress: String?
        /// What the panel was asked to load first — the cache candidate when it was a
        /// resumed address.
        var initialAddress = ""
        private var fired = false
        private var triedFallback = false
        private var triedCache = false
        private var urlObservation: NSKeyValueObservation?

        deinit { urlObservation?.invalidate() }

        /// A same-document navigation — an SPA tab via `pushState`, a `#hash` tab —
        /// fires NO navigation delegate callback, so `didCommit` never sees it and the
        /// resume address would be stuck on whatever loaded last. `url` is KVO-compliant
        /// and moves for both, and `remember` is idempotent, so this simply covers more.
        func watchAddress(of webView: WKWebView) {
            urlObservation?.invalidate()
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                guard let self = self else { return }
                NTPanelSession.remember(webView.url, trackerHost: self.trackerHost)
            }
        }

        // didCommit, NOT didFinish: on a heavy landing page didFinish arrives seconds
        // after the page is already visible and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            NTPanelSession.remember(webView.url, trackerHost: trackerHost)
            fire()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            NTPanelSession.remember(webView.url, trackerHost: trackerHost)
            // The jar is at its most interesting the moment a page settles: a sign-in
            // POST has landed by now.
            NTPanelCookies.snapshot()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is just an ordinary redirect — not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            // Once the page has painted, a failed navigation is just a failed navigation
            // inside a working session: WebKit shows its own error and the user can go
            // back. Recovery is only for a panel that never got off the ground.
            guard !fired else { return }
            recover(webView)
        }

        /// The ladder, in order: resumed address live -> tracker link live -> the same
        /// address from the on-disk cache -> give up and hand back the native app.
        private func recover(_ webView: WKWebView) {
            // 1. The resumed address is dead. Stop resuming it, and re-enter through the
            //    tracker link.
            if !triedFallback, let fallback = fallbackAddress, let url = URL(string: fallback) {
                triedFallback = true
                NTPanelSession.forget()
                webView.load(URLRequest(url: url))
                return
            }
            // 2. Nothing loads live — the radio dropped between the gate's verdict and the
            //    page. A stale page from disk still shows the user their account; a WebKit
            //    error page shows them nothing they can act on. Only worth trying for a
            //    real page: the tracker link is a 302 and has nothing cached worth having.
            if !triedCache, fallbackAddress != nil, let url = URL(string: initialAddress) {
                triedCache = true
                webView.load(URLRequest(url: url,
                                        cachePolicy: .returnCacheDataDontLoad,
                                        timeoutInterval: 15))
                return
            }
            // 3. Out of options.
            onDeadEnd?()
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
        // Explicit, because the signed-in session depends on it: the DEFAULT store is the
        // persistent, on-disk one. Never .nonPersistent().
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
        context.coordinator.initialAddress = ntAddress
        webView.navigationDelegate = context.coordinator
        context.coordinator.watchAddress(of: webView)
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
        // Cookies FIRST, then load. The other order signs the user out on every cold
        // start, and the loading screen is still up so the wait is invisible.
        let address = ntAddress
        NTPanelCookies.restore { [weak webView] in
            guard let webView = webView, let url = URL(string: address) else { return }
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // MUST NEVER reload: that would restart the page on every SwiftUI re-render.
    // Refreshing the callbacks is the only thing allowed here.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
    }
}
