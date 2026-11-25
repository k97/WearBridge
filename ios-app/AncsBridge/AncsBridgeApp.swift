import SwiftUI

@main
struct AncsBridgeApp: App {
    @StateObject private var bleViewModel = BLEViewModel()

    init() {
        // Before any scene: a tap on a quick reply notification may be what launches the app.
        QuickReplyLauncher.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleViewModel)
                .task { QuickReplyLauncher.shared.requestAuthorization() }
        }
    }
}
