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

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("✅ Application did finish launching", category: .lifecycle)
        setupDockIcon()
    }

    private func setupDockIcon() {
        // Since we are in an SPM project, resources are in the module bundle.
        #if os(macOS)
        DispatchQueue.main.async {
            AppLogger.shared.info("🛠 Setting up dock icon...", category: .ui)

            // Debug: List all images in Bundle.module if possible
            AppLogger.shared.info("📦 Bundle.module.bundleURL: \(Bundle.module.bundleURL.path)", category: .ui)

            // 1. Try loading by the asset name "AppIcon" from Bundle.module
            if let image = Bundle.module.image(forResource: "AppIcon") {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from Bundle.module (AppIcon)", category: .ui)
                return
            }

            // 2. Try loading by the file name "AIVideoLocal" from Bundle.module
            if let image = Bundle.module.image(forResource: "AIVideoLocal") {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from Bundle.module (AIVideoLocal)", category: .ui)
                return
            }

            // 3. Fallback to NSImage(named:) which sometimes works if the bundle is properly integrated
            if let image = NSImage(named: "AppIcon") {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from NSImage(named: AppIcon)", category: .ui)
                return
            }

            if let image = NSImage(named: "AIVideoLocal") {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from NSImage(named: AIVideoLocal)", category: .ui)
                return
            }

            // 4. Try loading direct file from Bundle.module
            if let image = Bundle.module.image(forResource: "AIVideoLocalDirect") {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from Bundle.module (AIVideoLocalDirect)", category: .ui)
                return
            }

            // 5. Try loading by full path from bundle
            let imagePath = Bundle.module.bundleURL.appendingPathComponent("AIVideoLocalDirect.png").path
            if let image = NSImage(contentsOfFile: imagePath) {
                NSApp.applicationIconImage = image
                AppLogger.shared.info("🎨 Dock icon updated from NSImage(contentsOfFile: \(imagePath))", category: .ui)
                return
            }

            AppLogger.shared.error("⚠️ Failed to find Dock icon in any known location", category: .ui)
        }
        #endif
    }

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
