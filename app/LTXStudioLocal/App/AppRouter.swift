import SwiftUI

enum AppScreen: String, CaseIterable, Identifiable {
    case home = "Home"
    case projectStudio = "Project Studio"
    case continuityLibrary = "Continuity Library"
    case modelManager = "Model Manager"
    case taskQueue = "Task Queue"
    case settings = "Settings"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .projectStudio: return "video"
        case .continuityLibrary: return "person.2.square.stack"
        case .modelManager: return "cpu"
        case .taskQueue: return "tray.and.arrow.down"
        case .settings: return "gearshape"
        }
    }
}

class AppRouter: ObservableObject {
    @Published var selectedScreen: AppScreen = .home
    @Published var selectedProjectID: String?
}
