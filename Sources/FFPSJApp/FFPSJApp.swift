import SwiftUI

@main
struct FFPSJApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .onOpenURL { container.handle(url: $0) }
        }
    }
}
