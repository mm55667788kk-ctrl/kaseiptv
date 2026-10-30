import Foundation

struct Genre: Identifiable, Hashable { let id: String; let title: String }
struct Channel: Identifiable, Hashable {
    let id: String; let name: String; let cmd: String
    let logo: String?; let genreId: String; let number: Int
}

enum StalkerError: LocalizedError {
    case badURL, noToken, badResponse
    var errorDescription: String? {
        switch self {
        case .badURL: return "رابط البوابة غير صحيح"
        case .noToken: return "فشل تسجيل الدخول: تأكد من الرابط والـ MAC"
        case .badResponse: return "رد غير متوقع من السيرفر"
        }
    }
}

final class StalkerClient {
    private let endpoint: URL
    private let mac: String
    private var token = ""
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()

    init(portal: String, mac: String) throws {
        var p = portal.trimmingCharacters(in: .whitespacesAndNewlines)
        while p.hasSuffix("/") { p.removeLast() }
        if !p.hasSuffix("load.php") { p += "/server/load.php" }
        guard let u = URL(string: p) else { throw StalkerError.badURL }
        endpoint = u
        self.mac = mac.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private func call(_ params: [String: String]) async throws -> [String: Any] {
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "JsHttpRequest", value: "1-xml"))
        comps.queryItems = items
        var req = URLRequest(url: comps.url!)
        req.setValue("mac=\(mac); stb_lang=en; timezone=GMT", forHTTPHeaderField: "Cookie")
        req.setValue("Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3", forHTTPHeaderField: "User-Agent")
        req.setValue("Model: MAG250; Link: WiFi", forHTTPHeaderField: "X-User-Agent")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let js = obj["js"] as? [String: Any] else { throw StalkerError.badResponse }
        return js
    }

    func login() async throws {
        let h = try await call(["type": "stb", "action": "handshake", "token": ""])
        guard let t = h["token"] as? String, !t.isEmpty else { throw StalkerError.noToken }
        token = t
        _ = try? await call(["type": "stb", "action": "get_profile"])
    }

    func genres() async throws -> [Genre] {
        let js = try await rawList(["type": "itv", "action": "get_genres"])
        return js.compactMap {
            guard let id = Self.str($0["id"]), let t = $0["title"] as? String, id != "*" else { return nil }
            return Genre(id: id, title: t)
        }
    }

    func channels() async throws -> [Channel] {
        let js = try await rawList(["type": "itv", "action": "get_all_channels"])
        return js.compactMap {
            guard let id = Self.str($0["id"]), let n = $0["name"] as? String,
                  let cmd = $0["cmd"] as? String else { return nil }
            let logo = ($0["logo"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return Channel(id: id, name: n, cmd: cmd, logo: logo,
                           genreId: Self.str($0["tv_genre_id"]) ?? "",
                           number: Int(Self.str($0["number"]) ?? "") ?? 0)
        }
    }

    /// يرجع رابط البث النهائي للقناة
    func streamURL(for ch: Channel) async throws -> URL {
        let js = try await call(["type": "itv", "action": "create_link", "cmd": ch.cmd])
        var s = (js["cmd"] as? String) ?? ch.cmd
        if let r = s.range(of: "http") { s = String(s[r.lowerBound...]) }
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)) else { throw StalkerError.badResponse }
        return u
    }

    private func rawList(_ p: [String: String]) async throws -> [[String: Any]] {
        let js = try await call(p)
        if let d = js["data"] as? [[String: Any]] { return d }
        if let a = js as? [String: Any], let d = a["data"] as? [String: Any] { return Array(d.values.compactMap { $0 as? [String: Any] }) }
        return []
    }

    private static func str(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }
}
