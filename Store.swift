import SwiftUI

@MainActor
final class Store: ObservableObject {
    @AppStorage("portal") var portal = ""
    @AppStorage("mac") var mac = ""
    @AppStorage("favs") private var favsRaw = "[]"

    @Published var genres: [Genre] = []
    @Published var channels: [Channel] = []
    @Published var loading = false
    @Published var error: String?
    @Published var loggedIn = false
    private(set) var client: StalkerClient?

    var favorites: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: Data(favsRaw.utf8))) ?? []) }
        set {
            objectWillChange.send()
            favsRaw = String(data: (try? JSONEncoder().encode(Array(newValue))) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        }
    }
    func toggleFav(_ c: Channel) {
        var f = favorites
        if f.contains(c.id) { f.remove(c.id) } else { f.insert(c.id) }
        favorites = f
    }

    func connect() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            let c = try StalkerClient(portal: portal, mac: mac)
            try await c.login()
            async let g = c.genres()
            async let ch = c.channels()
            genres = try await g
            channels = try await ch.sorted { $0.number < $1.number }
            client = c
            loggedIn = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() { loggedIn = false; channels = []; genres = [] }
}
