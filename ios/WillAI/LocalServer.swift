import Foundation
import Network

/// Server HTTP minimale su 127.0.0.1 che serve i file in `www`.
/// Origine fissa (http://127.0.0.1:47821): contesto sicuro per WebGPU/Cache API e dati persistenti stabili.
final class LocalServer {
    static let port: UInt16 = 47821
    private let root: URL
    private let queue = DispatchQueue(label: "willai.server")
    private var listener: NWListener?
    private(set) var isReady = false

    init(root: URL) { self.root = root.standardizedFileURL }

    func start(onReady: @escaping () -> Void) {
        if isReady { onReady(); return }
        listener?.cancel()
        let p = NWParameters.tcp
        p.allowLocalEndpointReuse = true
        p.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: Self.port)!)
        guard let l = try? NWListener(using: p) else { return }
        l.stateUpdateHandler = { [weak self, weak l] s in
            guard let self, let l, self.listener === l else { return }
            switch s {
            case .ready: self.isReady = true; onReady()
            case .failed, .cancelled: self.isReady = false
            default: break
            }
        }
        l.newConnectionHandler = { [weak self] c in self?.serve(c) }
        listener = l
        l.start(queue: queue)
    }

    private func serve(_ c: NWConnection) {
        c.start(queue: queue)
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, err in
            guard let self, let data, err == nil, let req = String(data: data, encoding: .utf8) else { c.cancel(); return }
            self.respond(req, c)
        }
    }

    private func respond(_ req: String, _ c: NWConnection) {
        let lines = req.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "HEAD" else { return send(c, 405, [:], Data()) }
        var path = String(parts[1].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]).removingPercentEncoding ?? "/"
        if path.hasSuffix("/") { path += "index.html" }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path), let file = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return send(c, 404, [:], Data("Not found".utf8))
        }
        var status = 200, body = file
        var h = ["Content-Type": mime(url.pathExtension), "Cache-Control": "no-cache", "Accept-Ranges": "bytes"]
        if let r = lines.first(where: { $0.lowercased().hasPrefix("range:") }), let (a, b) = range(r, file.count) {
            status = 206; body = file.subdata(in: a..<(b + 1)); h["Content-Range"] = "bytes \(a)-\(b)/\(file.count)"
        }
        send(c, status, h, parts[0] == "HEAD" ? Data() : body, length: body.count)
    }

    private func range(_ line: String, _ size: Int) -> (Int, Int)? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let r = line[line.index(after: eq)...].split(separator: "-", omittingEmptySubsequences: false)
        guard r.count == 2, let a = Int(r[0].trimmingCharacters(in: .whitespaces)), a < size else { return nil }
        let b = Int(r[1].trimmingCharacters(in: .whitespaces)).map { min($0, size - 1) } ?? size - 1
        return b >= a ? (a, b) : nil
    }

    private func send(_ c: NWConnection, _ status: Int, _ h: [String: String], _ body: Data, length: Int? = nil) {
        var head = "HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))\r\nConnection: close\r\nContent-Length: \(length ?? body.count)\r\n"
        for (k, v) in h { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        c.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in c.cancel() })
    }

    private func mime(_ e: String) -> String {
        switch e.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json", "webmanifest": return "application/json; charset=utf-8"
        case "wasm": return "application/wasm"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "ico": return "image/x-icon"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
