import SwiftUI

@main
struct LTXStudioLocalApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(appState)
                .environmentObject(appRouter)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
