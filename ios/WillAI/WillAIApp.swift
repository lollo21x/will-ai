import SwiftUI
import WebKit

@main
struct WillAIApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var host = WebHost()

    var body: some Scene {
        WindowGroup {
            WebView(host: host)
                .ignoresSafeArea()
                .background(Color(red: 0.055, green: 0.055, blue: 0.086))
                .preferredColorScheme(.dark)
        }
        .onChange(of: phase) { _, new in if new == .active { host.ensureServer() } }
    }
}

struct WebView: UIViewRepresentable {
    let host: WebHost
    func makeUIView(context: Context) -> WKWebView { host.webView }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

final class WebHost: NSObject, ObservableObject, WKUIDelegate, WKNavigationDelegate {
    let webView: WKWebView
    private let server: LocalServer
    private static let home = URL(string: "http://127.0.0.1:\(LocalServer.port)/index.html")!

    override init() {
        let www = Bundle.main.url(forResource: "www", withExtension: nil)!
        server = LocalServer(root: www)
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()   // archiviazione persistente (Cache API, OPFS, IndexedDB, localStorage)
        cfg.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        let bg = UIColor(red: 0.055, green: 0.055, blue: 0.086, alpha: 1)
        webView.isOpaque = false
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true
        webView.uiDelegate = self
        webView.navigationDelegate = self
        ensureServer()
    }

    func ensureServer() {
        server.start { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.webView.url == nil else { return }
                self.webView.load(URLRequest(url: Self.home))
            }
        }
    }

    // iOS può terminare il processo web sotto pressione di memoria: ricarica la pagina
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let u = action.request.url, u.host != "127.0.0.1" {
            UIApplication.shared.open(u); decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    // WKWebView non mostra alert()/confirm() da solo
    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: m, preferredStyle: .alert)
        a.addAction(.init(title: "OK", style: .default) { _ in completionHandler() })
        present(a)
    }
    func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: m, preferredStyle: .alert)
        a.addAction(.init(title: "Annulla", style: .cancel) { _ in completionHandler(false) })
        a.addAction(.init(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a)
    }
    private func present(_ vc: UIViewController) {
        var top = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(vc, animated: true)
    }
}
