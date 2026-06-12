import SwiftUI
import OSLog

@main
struct LTXStudioLocalApp: App {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "App")

    // Lazy initialize to avoid blocking App init
    @StateObject private var appState = AppState()
    @StateObject private var appRouter = AppRouter()

    init() {
        // Use NSLog for guaranteed visibility in system logs
        NSLog("🚀 LTXStudioLocalApp: init")
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appRouter)
                .onAppear {
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
                NSLog("✅ MainNavigationView: onAppear")
            }
    }
}
