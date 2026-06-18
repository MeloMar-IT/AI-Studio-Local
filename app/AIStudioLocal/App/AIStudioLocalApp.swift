import SwiftUI
import OSLog

@main
struct AIStudioLocalApp: App {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "App")

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Lazy initialize to avoid blocking App init
    @StateObject private var appState = AppState()
    @StateObject private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

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
                    appDelegate.appState = appState
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                AppLogger.shared.info("Application backgrounded", category: .lifecycle)
            }
            // scenePhase .inactive or .background doesn't always mean termination on macOS
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.info("🛑 Application will terminate", category: .lifecycle)
        appState?.stopWorkerSync()
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
