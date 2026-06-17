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
    @Published var isDownloading: Bool = false
    @Published var downloadJobId: String? = nil

    private let modelStore: ModelStore
    private var cancellables = Set<AnyCancellable>()

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
        fetchModels()
    }

    func fetchModels() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let fetchedModels = try await modelStore.fetchModels()
                self.models = fetchedModels

                // If we got mocks because of a network error, we can detect it if we want,
                // but for now let's just assume if we have models we are good.
                // In a real app, the fetchModels would throw or return a Result.

                if self.selectedModel == nil {
                    self.selectedModel = fetchedModels.first(where: { $0.recommended }) ?? fetchedModels.first
                }

                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.isOffline = true
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

    func downloadModel(modelId: String) {
        isDownloading = true
        errorMessage = nil
        downloadJobId = nil

        Task { @MainActor in
            do {
                let result = try await modelStore.downloadModel(modelId: modelId)
                if result.success {
                    self.downloadJobId = result.jobId
                    // In a real implementation, we would subscribe to job events here
                    // to show progress. For now, we'll just show that it started.
                    // We also refresh after some time or when user manually refreshes.

                    // Show a message that download started
                    self.errorMessage = "Download started for \(modelId). It will run in the background."
                } else {
                    self.errorMessage = result.message
                }
                self.isDownloading = false
            } catch {
                self.errorMessage = "Download failed: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }
}
