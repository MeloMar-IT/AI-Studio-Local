import SwiftUI
import OSLog

@main
struct AIStudioLocalApp: App {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "App")

    // Lazy initialize to avoid blocking App init
    @StateObject private var appState = AppState()
    @StateObject private var appRouter = AppRouter()

    init() {
        AppLogger.shared.info("🚀 AIStudioLocalApp: init", category: .lifecycle)
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appRouter)
                .onAppear {
                    AppLogger.shared.info("Application foregrounded", category: .lifecycle)
                    #if os(macOS)
                    // Ensure the app is treated as a foreground application
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appRouter: AppRouter

    var body: some View {
        MainNavigationView()
            .preferredColorScheme(.dark)
            .frame(minWidth: 1000, minHeight: 600)
            .onAppear {
                AppLogger.shared.info("✅ MainNavigationView: onAppear", category: .ui)
            }
    }
}
