import SwiftUI

@main
struct PhotoCoachApp: App {
    init() {
        _ = Metrics.launch // start the startup clock as early as the app can
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
