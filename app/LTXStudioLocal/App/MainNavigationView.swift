import SwiftUI

struct MainNavigationView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppScreen.allCases, selection: $router.selectedScreen) { screen in
                NavigationLink(value: screen) {
                    Label(screen.rawValue, systemImage: screen.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("LTX Studio")
        } detail: {
            ZStack {
                switch router.selectedScreen {
                case .home:
                    HomeDashboardView()
                case .projectStudio:
                    ProjectStudioView()
                case .continuityLibrary:
                    ContinuityLibraryView()
                case .modelManager:
                    ModelManagerView()
                case .renderQueue:
                    RenderQueueView()
                case .settings:
                    SettingsView()
                }

                if let error = appState.activeError {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                appState.activeError = nil
                            }

                        AppErrorView(error: error) {
                            appState.activeError = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: appState.activeError != nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct MainNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        MainNavigationView()
            .environmentObject(AppRouter())
            .environmentObject(AppState())
    }
}
