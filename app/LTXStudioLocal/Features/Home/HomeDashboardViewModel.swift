import SwiftUI
import Combine

class HomeDashboardViewModel: ObservableObject {
    @Published var recentProjects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let projectStore: ProjectStore
    private let settings: UserSettings
    private var cancellables = Set<AnyCancellable>()

    init(projectStore: ProjectStore = FileProjectStore(), settings: UserSettings = .shared) {
        self.projectStore = projectStore
        self.settings = settings
        loadRecentProjects()
    }

    func loadRecentProjects() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let projectsURL = self.settings.projectsURL
            let fileManager = FileManager.default

            do {
                let projectFolders = try fileManager.contentsOfDirectory(at: projectsURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)

                var loadedProjects: [Project] = []

                for folderURL in projectFolders where folderURL.pathExtension == "ltxproject" {
                    do {
                        let (project, _) = try self.projectStore.load(from: folderURL)
                        loadedProjects.append(project)
                    } catch {
                        print("Failed to load project at \(folderURL): \(error)")
                    }
                }

                // Sort by modified date descending
                loadedProjects.sort { $0.modifiedAt > $1.modifiedAt }

                // Take top 5 for "recent"
                let recent = Array(loadedProjects.prefix(5))

                DispatchQueue.main.async {
                    self.recentProjects = recent
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
