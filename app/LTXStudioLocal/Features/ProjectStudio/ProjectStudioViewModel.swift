import Foundation
import SwiftUI
import Combine

class ProjectStudioViewModel: ObservableObject {
    @Published var project: Project?
    @Published var scenes: [Scene] = []
    @Published var selectedSceneId: String? {
        didSet {
            // Reset active generation when scene changes
            activeGenerationId = scenes.first(where: { $0.id == selectedSceneId })?.generations.last?.id
        }
    }
    @Published var activeGenerationId: String?
    @Published var isGenerating: Bool = false
    @Published var isExporting: Bool = false
    @Published var lastExport: ExportMetadata?
    @Published var improvedPrompt: ImprovedPrompt?
    @Published var isShowingPromptComparison: Bool = false

    // Retake state
    @Published var retakeStartSeconds: Double = 0
    @Published var retakeEndSeconds: Double = 5
    @Published var retakePrompt: String = ""

    private let promptComposer: PromptComposer = DefaultPromptComposer()
    private let promptImprovementHelper: PromptImprovementHelper = DefaultPromptImprovementHelper()
    private let continuityStore: ContinuityStore = FileContinuityStore()
    private let generationClient: GenerationClient = HTTPGenerationClient()
    private let exportService: ExportService = MockExportService()
    private let projectStore: ProjectStore = FileProjectStore()
    private let sceneResolver: SceneResolver = DefaultSceneResolver()
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    @Published var availableModels: [ModelProfile] = []
    @Published var resolvedElements: [String: [ResolvedSceneElement]] = [:]
    @Published var missingElementsWarning: String? = nil

    var selectedScene: Scene? {
        scenes.first { $0.id == selectedSceneId }
    }

    init() {
        fetchAvailableModels()

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

        NotificationCenter.default.publisher(for: .openProject)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let (project, scenes) = notification.object as? (Project, [Scene]) {
                    self?.selectProject(project, scenes: scenes)
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
        resolveAllSceneElements()
        if self.selectedSceneId == nil {
            self.selectedSceneId = scenes.first?.id
        }
    }

    private func resolveAllSceneElements() {
        var newResolved: [String: [ResolvedSceneElement]] = [:]
        var missingCount = 0

        for scene in scenes {
            do {
                let resolved = try sceneResolver.resolve(scene: scene)
                newResolved[scene.id] = resolved
                missingCount += resolved.filter { $0.isMissing }.count
            } catch {
                print("Failed to resolve elements for scene \(scene.id): \(error)")
            }
        }

        self.resolvedElements = newResolved

        if missingCount > 0 {
            self.missingElementsWarning = "\(missingCount) referenced continuity elements are missing from your library."
        } else {
            self.missingElementsWarning = nil
        }
    }

    private func fetchAvailableModels() {
        Task { @MainActor in
            do {
                let modelStore = RemoteModelStore(generationClient: self.generationClient)
                self.availableModels = try await modelStore.fetchModels()
            } catch {
                self.availableModels = ModelProfile.mocks
            }
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

    func updateSceneMode(_ sceneId: String, mode: SceneMode) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            // Check if mode is supported by selected model
            if let modelId = project?.modelProfileId,
               let model = availableModels.first(where: { $0.id == modelId }) {
                let modeString: String
                switch mode {
                case .textToVideo: modeString = "text-to-video"
                case .imageToVideo: modeString = "image-to-video"
                case .audioToVideo: modeString = "audio-to-video"
                case .retake: modeString = "retake"
                }

                if !model.supportedModes.contains(modeString) {
                    appState?.showError(AppError.generationFailed(details: "The selected model does not support \(modeString)."))
                    return
                }
            }

            scenes[index].mode = mode
            updateProject()
        }
    }

    func updateSceneNegativePrompt(_ sceneId: String, prompt: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].negativePrompt = prompt.isEmpty ? nil : prompt
            updateProject()
        }
    }

    func updateSceneAdvancedSettings(_ sceneId: String, seed: Int? = nil, inferenceSteps: Int? = nil, guidanceScale: Float? = nil, fps: Int? = nil, frameCount: Int? = nil, modelProfileId: String? = nil, upscalerId: String? = nil, quantizationMode: String? = nil) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            if let seed = seed { scenes[index].seed = seed }
            if let inferenceSteps = inferenceSteps { scenes[index].inferenceSteps = inferenceSteps }
            if let guidanceScale = guidanceScale { scenes[index].guidanceScale = guidanceScale }
            if let fps = fps { scenes[index].fps = fps }
            if let frameCount = frameCount { scenes[index].frameCount = frameCount }
            if let modelProfileId = modelProfileId { scenes[index].modelProfileId = modelProfileId }
            if let upscalerId = upscalerId { scenes[index].upscalerId = upscalerId }
            if let quantizationMode = quantizationMode { scenes[index].quantizationMode = quantizationMode }
            updateProject()
        }
    }

    func resetSceneAdvancedSettings(_ sceneId: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].seed = nil
            scenes[index].inferenceSteps = nil
            scenes[index].guidanceScale = nil
            scenes[index].fps = nil
            scenes[index].frameCount = nil
            scenes[index].modelProfileId = nil
            scenes[index].loraWeights = nil
            scenes[index].upscalerId = nil
            scenes[index].quantizationMode = nil
            updateProject()
        }
    }

    func updateSceneDuration(_ sceneId: String, duration: Double) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].durationSeconds = duration
            updateProject()
        }
    }

    func updateReferenceImage(_ sceneId: String, path: String?) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].referenceImagePath = path
            updateProject()
        }
    }

    func updateAudioMode(_ sceneId: String, mode: AudioMode) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].audioMode = mode
            updateProject()
        }
    }

    func updateAudioReference(_ sceneId: String, path: String?) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].audioReferencePath = path
            updateProject()
        }
    }

    func improvePrompt(for sceneId: String) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        let currentPrompt = scenes[index].prompt
        improvedPrompt = promptImprovementHelper.improve(currentPrompt)
        isShowingPromptComparison = true
    }

    func acceptImprovedPrompt(for sceneId: String) {
        guard let improved = improvedPrompt else { return }
        updateScenePrompt(sceneId, prompt: improved.improved)
        improvedPrompt = nil
        isShowingPromptComparison = false
    }

    func rejectImprovedPrompt() {
        improvedPrompt = nil
        isShowingPromptComparison = false
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

    func detachElement(_ sceneId: String, elementId: String, type: ContinuityElementType) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].attachedContinuityElements.removeAll { $0.elementId == elementId }
            updateProject()
        }
    }

    func exportProject(preset: ExportPreset, projectURL: URL) {
        guard let project = project else { return }

        isExporting = true

        Task {
            do {
                let metadata = try await exportService.exportProject(
                    project,
                    scenes: scenes,
                    preset: preset,
                    projectURL: projectURL
                )

                // Save to project store as well
                try projectStore.saveExportMetadata(metadata, to: projectURL)

                await MainActor.run {
                    self.isExporting = false
                    self.lastExport = metadata
                    // Optionally notify user
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.appState?.activeError = AppError.exportFailed(error: error)
                }
            }
        }
    }

    func duplicateScene(_ sceneId: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            var newScene = scenes[index]
            newScene = Scene(
                name: "\(newScene.name) (Copy)",
                mode: newScene.mode,
                prompt: newScene.prompt,
                negativePrompt: newScene.negativePrompt,
                durationSeconds: newScene.durationSeconds,
                aspectRatio: newScene.aspectRatio,
                resolution: newScene.resolution,
                attachedContinuityElements: newScene.attachedContinuityElements,
                consistencyLocks: newScene.consistencyLocks,
                generations: [] // Do not duplicate generations
            )
            scenes.insert(newScene, at: index + 1)
            selectedSceneId = newScene.id
            updateProject()
        }
    }

    func moveScene(from source: IndexSet, to destination: Int) {
        scenes.move(fromOffsets: source, toOffset: destination)
        updateProject()
    }

    private func updateProject() {
        project?.scenes = scenes.map { $0.id }

        // Sync timeline
        var currentTime: Double = 0
        let clips = scenes.map { scene -> TimelineClip in
            let clip = TimelineClip(sceneId: scene.id, startTime: currentTime, duration: scene.durationSeconds)
            currentTime += scene.durationSeconds
            return clip
        }
        project?.timeline = Timeline(clips: clips)

        project?.modifiedAt = Date()
        resolveAllSceneElements()
    }

    func removeMissingElement(_ sceneId: String, elementId: String) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].attachedContinuityElements.removeAll { $0.elementId == elementId }
            updateProject()
        }
    }

    func replaceMissingElement(_ sceneId: String, oldElementId: String, newElementId: String, type: ContinuityElementType) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            if let elementIndex = scenes[index].attachedContinuityElements.firstIndex(where: { $0.elementId == oldElementId }) {
                scenes[index].attachedContinuityElements[elementIndex] = AttachedContinuityElement(elementId: newElementId, type: type)
                updateProject()
            }
        }
    }

    func generateScene() {
        guard let scene = selectedScene, let project = project, let appState = appState else { return }

        if !appState.isWorkerAvailable {
            appState.activeError = AppError.workerUnavailable()
            return
        }

        if !appState.hardwareProfile.isLocalModeReady {
            appState.activeError = AppError.unsupportedMac(reason: "Insufficient memory or non-Apple Silicon hardware.")
            return
        }

        isGenerating = true
        let composed = composePrompt(for: scene)

        let request = GenerationRequest(
            prompt: scene.mode == .retake ? retakePrompt : composed.prompt,
            negativePrompt: composed.negativePrompt,
            modelId: "ltx-video-v1", // Default model for now
            projectId: project.id,
            sceneId: scene.id,
            imagePath: scene.mode == .imageToVideo ? scene.referenceImagePath : nil,
            audioPath: (scene.mode == .audioToVideo || scene.audioMode == .imported || scene.audioMode == .voiceover) ? scene.audioReferencePath : nil,
            retakeStartSeconds: scene.mode == .retake ? retakeStartSeconds : nil,
            retakeEndSeconds: scene.mode == .retake ? retakeEndSeconds : nil
        )

        Task {
            do {
                let jobId: String
                switch scene.mode {
                case .textToVideo:
                    jobId = try await generationClient.submitTextToVideo(request: request)
                case .imageToVideo:
                    jobId = try await generationClient.submitImageToVideo(request: request)
                case .audioToVideo:
                    jobId = try await generationClient.submitAudioToVideo(request: request)
                case .retake:
                    jobId = try await generationClient.submitRetake(request: request)
                }

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
                    appState.addJob(job)
                    isGenerating = false
                }
            } catch let error as GenerationClientError {
                await MainActor.run {
                    isGenerating = false
                    appState.activeError = error.asAppError
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    appState.activeError = AppError.generationFailed(details: error.localizedDescription) { [weak self] in
                        self?.generateScene()
                    }
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
        activeGenerationId = generation.id
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

                // If it's the current scene, set it as active
                if job.sceneId == selectedSceneId {
                    activeGenerationId = newGeneration.id
                }

                updateProject()
            }
        }
    }
}
