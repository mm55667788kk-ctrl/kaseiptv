import SwiftUI

@main
struct IPTVApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            Group {
                if store.loggedIn { ChannelsView() } else { LoginView() }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
        }
    }
}
