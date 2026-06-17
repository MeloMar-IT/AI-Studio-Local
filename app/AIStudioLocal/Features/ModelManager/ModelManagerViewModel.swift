import Foundation
import Combine
import SwiftUI

class ModelManagerViewModel: ObservableObject {
    @Published var models: [ModelProfile] = []
    @Published var selectedModel: ModelProfile?
    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false
    @Published var errorMessage: String?
    @Published var importValidationResult: ModelValidationResponse?
    @Published var isImporting: Bool = false

    @Published var isDeleting: Bool = false

    private let modelStore: ModelStore
    private let generationClient: GenerationClient
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: Task<Void, Never>?

    init(modelStore: ModelStore, appState: AppState, generationClient: GenerationClient = HTTPGenerationClient()) {
        self.modelStore = modelStore
        self.appState = appState
        self.generationClient = generationClient
        fetchModels()
        checkForExistingDownloads()
    }

    private func checkForExistingDownloads() {
        // We sync with appState.activeJobs to identify models currently being downloaded
        appState.$activeJobs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Forcing UI update if active jobs change
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func isDownloading(modelId: String) -> Bool {
        return appState.activeJobs.contains { job in
            job.sceneId == modelId &&
            job.mode == .modelDownload &&
            (job.status == .downloading || job.status == .queued)
        }
    }

    func downloadProgress(for modelId: String) -> Double {
        return appState.activeJobs.first { job in
            job.sceneId == modelId && job.mode == .modelDownload && (job.status == .downloading || job.status == .queued)
        }?.progress ?? 0
    }

    func downloadStatus(for modelId: String) -> String {
        guard let job = appState.activeJobs.first(where: { job in
            job.sceneId == modelId && job.mode == .modelDownload && (job.status == .downloading || job.status == .queued)
        }) else { return "" }

        if job.status == .queued {
            return "Queued..."
        }
        return job.message ?? "Downloading..."
    }

    func fetchModels(isBackground: Bool = false) {
        if !isBackground {
            isLoading = true
        }
        errorMessage = nil

        Task { @MainActor in
            do {
                let fetchedModels = try await modelStore.fetchModels()
                self.models = fetchedModels

                if self.selectedModel == nil {
                    self.selectedModel = fetchedModels.first(where: { $0.recommended }) ?? fetchedModels.first
                } else if let currentSelected = self.selectedModel {
                    // Update the selected model from the new list if it exists
                    self.selectedModel = fetchedModels.first(where: { $0.id == currentSelected.id })
                }

                self.isLoading = false
            } catch {
                if !isBackground {
                    self.errorMessage = error.localizedDescription
                    self.isOffline = true
                }
                self.isLoading = false
            }
        }
    }

    func selectModel(_ model: ModelProfile) {
        selectedModel = model
    }

    func validateModelFolder(at path: String) {
        isLoading = true
        errorMessage = nil
        importValidationResult = nil

        Task { @MainActor in
            do {
                let result = try await modelStore.validateModelFolder(path: path)
                self.importValidationResult = result
                self.isLoading = false
            } catch {
                self.errorMessage = "Validation failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func importModel(at path: String, copy: Bool, modelId: String?) {
        isImporting = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let result = try await modelStore.importModel(path: path, copy: copy, modelId: modelId)
                if result.success {
                    // Refresh models after successful import
                    fetchModels()
                    NotificationCenter.default.post(name: .modelsUpdated, object: nil)
                    self.importValidationResult = nil
                } else {
                    self.errorMessage = result.message
                }
                self.isImporting = false
            } catch {
                self.errorMessage = "Import failed: \(error.localizedDescription)"
                self.isImporting = false
            }
        }
    }

    func deleteModel(modelId: String) {
        isDeleting = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let result = try await modelStore.deleteModel(modelId: modelId)
                if result.success {
                    fetchModels()
                    NotificationCenter.default.post(name: .modelsUpdated, object: nil)
                } else {
                    self.errorMessage = result.message
                }
                self.isDeleting = false
            } catch {
                self.errorMessage = "Deletion failed: \(error.localizedDescription)"
                self.isDeleting = false
            }
        }
    }

    func downloadModel(modelId: String) {
        errorMessage = nil

        Task { @MainActor in
            do {
                let result = try await modelStore.downloadModel(modelId: modelId)
                if result.success, let jobId = result.jobId {
                    // Create a job for the Task Queue
                    let modelName = self.models.first(where: { $0.id == modelId })?.name ?? modelId
                    let downloadJob = GenerationJob(
                        id: jobId,
                        projectId: "system",
                        sceneId: modelId,
                        status: .queued,
                        mode: .modelDownload,
                        progress: 0,
                        startedAt: Date(),
                        sceneName: "Download: \(modelName)"
                    )
                    self.appState.addJob(downloadJob)
                } else {
                    self.errorMessage = result.message
                }
            } catch {
                self.errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }
}
