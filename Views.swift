import SwiftUI
import AVKit

struct LoginView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.15), .black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "play.tv.fill").font(.system(size: 64)).foregroundStyle(.cyan)
                Text("IPTV Player").font(.largeTitle.bold())
                field("Portal URL  http://host/c/", text: $store.portal, icon: "link")
                field("MAC  00:1A:79:XX:XX:XX", text: $store.mac, icon: "number")
                if let e = store.error { Text(e).foregroundStyle(.red).font(.footnote) }
                Button {
                    Task { await store.connect() }
                } label: {
                    Group {
                        if store.loading { ProgressView() } else { Text("دخول").bold() }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
                }
                .disabled(store.loading || store.portal.isEmpty || store.mac.isEmpty)
            }
            .padding(24)
        }
    }
    func field(_ ph: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.secondary)
            TextField(ph, text: text).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ChannelsView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var genre: String? = nil     // nil = الكل, "fav" = المفضلة
    @State private var playing: Channel?

    var filtered: [Channel] {
        store.channels.filter { c in
            (query.isEmpty || c.name.localizedCaseInsensitiveContains(query)) &&
            (genre == nil || (genre == "fav" ? store.favorites.contains(c.id) : c.genreId == genre))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("الكل", nil); chip("★ المفضلة", "fav")
                        ForEach(store.genres) { chip($0.title, $0.id) }
                    }.padding(.horizontal)
                }.padding(.vertical, 8)
                List(filtered) { ch in
                    Button { playing = ch } label: { row(ch) }
                        .listRowBackground(Color.clear)
                        .swipeActions { Button { store.toggleFav(ch) } label: { Label("مفضلة", systemImage: "star") }.tint(.yellow) }
                }
                .listStyle(.plain)
            }
            .navigationTitle("القنوات")
            .searchable(text: $query, prompt: "ابحث عن قناة")
            .toolbar { Button("خروج") { store.logout() } }
        }
        .fullScreenCover(item: $playing) { PlayerView(channel: $0) }
    }

    func chip(_ t: String, _ id: String?) -> some View {
        Button { genre = id } label: {
            Text(t).font(.subheadline).padding(.horizontal, 14).padding(.vertical, 7)
                .background(genre == id ? Color.cyan : Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(genre == id ? .black : .white)
        }
    }

    func row(_ ch: Channel) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: ch.logo.flatMap(URL.init)) { $0.resizable().scaledToFit() } placeholder: {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Text(ch.name).foregroundStyle(.white).lineLimit(1)
            Spacer()
            if store.favorites.contains(ch.id) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let channel: Channel
    @State private var player: AVPlayer?
    @State private var error: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let player { VideoPlayer(player: player).ignoresSafeArea() }
            else if let error { Text(error).foregroundStyle(.red).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            Button { player?.pause(); dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.8)).padding()
            }
        }
        .task {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            do {
                let url = try await store.client!.streamURL(for: channel)
                let p = AVPlayer(url: url); player = p; p.play()
            } catch { self.error = error.localizedDescription }
        }
        .onDisappear { player?.pause() }
    }
}
