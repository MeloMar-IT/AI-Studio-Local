import SwiftUI
import Combine

class TaskQueueViewModel: ObservableObject {
    @Published var jobs: [GenerationJob] = []
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState

        // Subscribe to appState.activeJobs
        appState.$activeJobs
            .receive(on: RunLoop.main)
            .sink { [weak self] activeJobs in
                self?.jobs = activeJobs.reversed()
            }
            .store(in: &cancellables)
    }

    func clearCompletedJobs() {
        appState.clearCompletedJobs()
    }

    func cancelJob(_ job: GenerationJob) {
        appState.cancelJob(job)
    }
}
