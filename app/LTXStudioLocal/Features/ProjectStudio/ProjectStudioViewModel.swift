import Foundation
import SwiftUI
import Combine

class ProjectStudioViewModel: ObservableObject {
    @Published var project: Project?
    @Published var scenes: [Scene] = []
    @Published var selectedSceneId: String?
    @Published var isGenerating: Bool = false

    private let promptComposer: PromptComposer = DefaultPromptComposer()
    private let continuityStore: ContinuityStore = FileContinuityStore()
    private let generationClient: GenerationClient = HTTPGenerationClient()
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    var selectedScene: Scene? {
        scenes.first { $0.id == selectedSceneId }
    }

    init() {
        NotificationCenter.default.publisher(for: .generationCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let job = notification.object as? GenerationJob {
                    self?.handleGenerationCompleted(job)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .selectScene)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let sceneId = notification.object as? String {
                    self?.selectedSceneId = sceneId
                }
            }
            .store(in: &cancellables)
    }

    func setAppState(_ appState: AppState) {
        self.appState = appState
    }

    func composePrompt(for scene: Scene) -> ComposedPrompt {
        let elementIds = scene.attachedContinuityElements.map { $0.elementId }
        let allElements = (try? continuityStore.loadAll()) ?? []
        let attachedElements = allElements.filter { elementIds.contains($0.id) }

        return promptComposer.compose(scene: scene, elements: attachedElements)
    }

    func selectProject(_ project: Project, scenes: [Scene]) {
        self.project = project
        self.scenes = scenes
        if self.selectedSceneId == nil {
            self.selectedSceneId = scenes.first?.id
        }
    }

    func addScene() {
        let newScene = Scene(name: "New Scene \(scenes.count + 1)")
        scenes.append(newScene)
        selectedSceneId = newScene.id
        updateProject()
    }

    func deleteScene(_ sceneId: String) {
        scenes.removeAll { $0.id == sceneId }
        if selectedSceneId == sceneId {
            selectedSceneId = scenes.first?.id
        }
        updateProject()
    }

    func renameScene(_ sceneId: String, newName: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].name = newName
            updateProject()
        }
    }

    func updateScenePrompt(_ sceneId: String, prompt: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].prompt = prompt
            updateProject()
        }
    }

    func toggleLock(_ sceneId: String, keyPath: WritableKeyPath<ConsistencyLocks, Bool>) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].consistencyLocks[keyPath: keyPath].toggle()
            updateProject()
        }
    }

    func attachElement(_ sceneId: String, elementId: String, type: ContinuityElementType) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            // Avoid duplicates
            if !scenes[index].attachedContinuityElements.contains(where: { $0.elementId == elementId }) {
                scenes[index].attachedContinuityElements.append(
                    AttachedContinuityElement(elementId: elementId, type: type)
                )
                updateProject()
            }
        }
    }

    func removeElement(_ sceneId: String, elementId: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].attachedContinuityElements.removeAll { $0.elementId == elementId }
            updateProject()
        }
    }

    private func updateProject() {
        project?.scenes = scenes.map { $0.id }
        // In a real app, we would also update the timeline here if needed
        // and trigger a save via ProjectStore
        project?.modifiedAt = Date()
    }

    func generateScene() {
        guard let scene = selectedScene, let project = project else { return }

        isGenerating = true
        let composed = composePrompt(for: scene)

        let request = GenerationRequest(
            prompt: composed.prompt,
            negativePrompt: composed.negativePrompt,
            modelId: "ltx-video-v1", // Default model for now
            projectId: project.id,
            sceneId: scene.id
        )

        Task {
            do {
                let jobId = try await generationClient.submitTextToVideo(request: request)

                let job = GenerationJob(
                    id: jobId,
                    projectId: project.id,
                    sceneId: scene.id,
                    status: .queued,
                    mode: scene.mode,
                    modelProfile: ModelProfileSummary(id: "ltx-video-v1", name: "LTX Video v1"),
                    progress: 0,
                    startedAt: Date(),
                    sceneName: scene.name
                )

                await MainActor.run {
                    appState?.addJob(job)
                    isGenerating = false
                }
            } catch {
                print("Failed to submit generation job: \(error)")
                await MainActor.run {
                    isGenerating = false
                    // Handle error (e.g., show an alert)
                }
            }
        }
    }

    func deleteGeneration(_ generationId: String) {
        if let sceneIndex = scenes.firstIndex(where: { $0.id == selectedSceneId }) {
            scenes[sceneIndex].generations.removeAll { $0.id == generationId }
            updateProject()
        }
    }

    func useGeneration(_ generation: SceneGeneration) {
        // In a real app, this might update the scene's current output reference
        // For MVP, we'll just log it
        print("Using generation: \(generation.id)")
    }

    func regenerateFromSettings(_ generation: SceneGeneration) {
        guard let project = project else { return }

        isGenerating = true

        let request = GenerationRequest(
            prompt: generation.composedPrompt,
            negativePrompt: generation.negativePrompt,
            modelId: generation.modelProfile?.id ?? "ltx-video-v1",
            projectId: project.id,
            sceneId: generation.sceneId
        )

        Task {
            do {
                let jobId = try await generationClient.submitTextToVideo(request: request)

                let job = GenerationJob(
                    id: jobId,
                    projectId: project.id,
                    sceneId: generation.sceneId,
                    status: .queued,
                    mode: .textToVideo,
                    modelProfile: generation.modelProfile,
                    progress: 0,
                    startedAt: Date(),
                    sceneName: selectedScene?.name
                )

                await MainActor.run {
                    appState?.addJob(job)
                    isGenerating = false
                }
            } catch {
                print("Failed to submit generation job: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }

    private func handleGenerationCompleted(_ job: GenerationJob) {
        if let index = scenes.firstIndex(where: { $0.id == job.sceneId }) {
            let scene = scenes[index]
            let composed = composePrompt(for: scene)

            let newGeneration = SceneGeneration(
                id: job.id,
                sceneId: job.sceneId,
                outputPath: job.outputPaths?.video,
                previewImagePath: job.outputPaths?.preview,
                composedPrompt: composed.prompt,
                negativePrompt: composed.negativePrompt,
                modelProfile: job.modelProfile,
                seed: nil, // Would come from job metadata in real app
                resolution: scene.resolution,
                duration: scene.durationSeconds,
                createdAt: Date(),
                metadataPath: job.outputPaths?.metadata
            )

            if !scenes[index].generations.contains(where: { $0.id == job.id }) {
                scenes[index].generations.append(newGeneration)
                updateProject()
            }
        }
    }
}
