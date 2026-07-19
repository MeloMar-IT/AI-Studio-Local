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
    private let exportService: ExportService = AVFoundationExportService()
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
        NSLog("📁 ProjectStudioViewModel: init started")
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
                NSLog("📁 ProjectStudioViewModel: Received .openProject notification in sink")
                if let (project, scenes) = notification.object as? (Project, [Scene]) {
                    self?.selectProject(project, scenes: scenes)
                } else {
                    NSLog("📁 ProjectStudioViewModel: .openProject notification object casting failed: \(String(describing: notification.object))")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .modelsUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchAvailableModels()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .continuityLibraryUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                NSLog("📁 ProjectStudioViewModel: Received .continuityLibraryUpdated notification, resolving elements")
                self?.resolveAllSceneElements()
            }
            .store(in: &cancellables)
    }

    func setAppState(_ appState: AppState) {
        self.appState = appState
    }

    func composePrompt(for scene: Scene) -> ComposedPrompt {
        let elementIds = scene.attachedContinuityElements.map { $0.elementId }

        // Use AppState's continuityElements if available for better synchronization,
        // otherwise fallback to loading from disk.
        let allElements: [ContinuityElement]
        if let appState = self.appState {
            allElements = appState.continuityElements
        } else {
            allElements = (try? continuityStore.loadAll()) ?? []
        }

        let attachedElements = allElements.filter { elementIds.contains($0.id) }

        NSLog("🎨 ProjectStudioViewModel: Composing prompt for scene \(scene.id). Attached elements count: \(attachedElements.count)")
        for element in attachedElements {
            NSLog("🎨 ProjectStudioViewModel:   - Attached: \(element.name) (\(element.type.rawValue)) ID: \(element.id)")
            if element.type == .character {
                if let lora = element.trainedLoraPath {
                    NSLog("🎬 ProjectStudioViewModel: Character \(element.name) has LoRA: \(lora)")
                } else {
                    NSLog("🎬 ProjectStudioViewModel: Character \(element.name) has NO LoRA path")
                }
            }
        }

        return promptComposer.compose(scene: scene, elements: attachedElements)
    }

    func selectProject(_ project: Project, scenes: [Scene]) {
        NSLog("📁 ProjectStudioViewModel: selectProject called for \(project.name) (ID: \(project.id)) with \(scenes.count) scenes")
        self.project = project
        self.scenes = scenes
        resolveAllSceneElements()
        if self.selectedSceneId == nil || !scenes.contains(where: { $0.id == self.selectedSceneId }) {
            self.selectedSceneId = scenes.first?.id
            NSLog("📁 ProjectStudioViewModel: selectedSceneId set to \(self.selectedSceneId ?? "nil")")
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
                AppLogger.shared.error("Failed to resolve elements for scene \(scene.id): \(error)", category: .project)
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
                self.availableModels = []
                AppLogger.shared.error("Failed to fetch models: \(error.localizedDescription)", category: .worker)
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
                case .modelDownload: modeString = "model-download"
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

    func updateSceneResolution(_ sceneId: String, resolution: SceneResolution?) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].resolution = resolution
            updateProject()
        }
    }

    func updateSceneAdvancedSettings(_ sceneId: String, seed: Int? = nil, inferenceSteps: Int? = nil, guidanceScale: Float? = nil, fps: Int? = nil, frameCount: Int? = nil, resolution: SceneResolution? = nil, modelProfileId: String? = nil, upscalerId: String? = nil, quantizationMode: String? = nil) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            if let seed = seed { scenes[index].seed = seed }
            if let inferenceSteps = inferenceSteps { scenes[index].inferenceSteps = inferenceSteps }
            if let guidanceScale = guidanceScale { scenes[index].guidanceScale = guidanceScale }
            if let fps = fps { scenes[index].fps = fps }
            if let frameCount = frameCount { scenes[index].frameCount = frameCount }
            if let resolution = resolution { scenes[index].resolution = resolution }
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
        NSLog("🎬 ProjectStudioViewModel: generateScene() called")
        guard let scene = selectedScene, let project = project, let appState = appState else {
            NSLog("🎬 ProjectStudioViewModel: generateScene() aborted - missing dependencies (scene: \(selectedScene != nil), project: \(project != nil), appState: \(appState != nil))")
            return
        }

        NSLog("🎬 ProjectStudioViewModel: Generating scene '\(scene.name)' (ID: \(scene.id)) for project '\(project.name)'")

        if !appState.isWorkerAvailable {
            NSLog("🎬 ProjectStudioViewModel: generateScene() aborted - worker not available")
            appState.activeError = AppError.workerUnavailable()
            return
        }

        if !appState.hardwareProfile.isLocalModeReady {
            NSLog("🎬 ProjectStudioViewModel: generateScene() aborted - local mode not ready (hardware profile: \(appState.hardwareProfile))")
            appState.activeError = AppError.unsupportedMac(reason: "Insufficient memory or non-Apple Silicon hardware.")
            return
        }

        isGenerating = true
        appState.isLoading = true // Show loading overlay or feedback
        let composed = composePrompt(for: scene)
        NSLog("🎬 ProjectStudioViewModel: Composed prompt: \(composed.prompt.prefix(100))...")

        let modelId = scene.modelProfileId ?? project.modelProfileId ?? "ltx-video-av-q4"
        let modelName = availableModels.first(where: { $0.id == modelId })?.name ?? "LTX Video AV Q4"

        // Calculate frames based on duration and FPS.
        // Note: Increasing duration beyond 10s (up to 60s) will significantly increase generation time and memory usage.
        let request = GenerationRequest(
            prompt: scene.mode == .retake ? retakePrompt : composed.prompt,
            negativePrompt: composed.negativePrompt.isEmpty ? nil : composed.negativePrompt,
            width: scene.resolution?.width ?? 704,
            height: scene.resolution?.height ?? 512,
            numFrames: Int((scene.durationSeconds * Double(scene.fps ?? 24))),
            steps: scene.inferenceSteps ?? 20,
            guidanceScale: Double(scene.guidanceScale ?? 3.0),
            seed: scene.seed,
            enhancePrompt: true, // Enable prompt enhancement by default for better quality
            useUncensoredEnhancer: false,
            modelId: modelId,
            projectId: project.id,
            sceneId: scene.id,
            composedPrompt: composed.prompt,
            imagePath: scene.mode == .imageToVideo ? scene.referenceImagePath : nil,
            referenceImagePaths: composed.referenceImagePaths,
            audioPath: (scene.mode == .audioToVideo || scene.audioMode == .imported || scene.audioMode == .voiceover) ? scene.audioReferencePath : nil,
            voiceCloneReferencePath: composed.metadata["voice_clone_reference_path"],
            retakeStartSeconds: scene.mode == .retake ? retakeStartSeconds : nil,
            retakeEndSeconds: scene.mode == .retake ? retakeEndSeconds : nil,
            loras: composed.loras
        )

        NSLog("🎬 ProjectStudioViewModel: Prepared request with \(composed.loras.count) LoRAs")
        for lora in composed.loras {
            NSLog("🎬 ProjectStudioViewModel:   - LoRA: \(lora.path) (scale: \(lora.scale))")
        }

        Task {
            do {
                NSLog("🎬 ProjectStudioViewModel: Submitting generation request to client (mode: \(scene.mode), model: \(modelId))")
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
                case .modelDownload:
                    // Model downloads should not be triggered from ProjectStudio
                    throw GenerationClientError.invalidRequest("Model download cannot be initiated from scene generation.")
                }

                NSLog("🎬 ProjectStudioViewModel: Generation submitted successfully, job ID: \(jobId)")

                let job = GenerationJob(
                    id: jobId,
                    projectId: project.id,
                    sceneId: scene.id,
                    status: .queued,
                    mode: scene.mode,
                    modelProfile: ModelProfileSummary(id: modelId, name: modelName),
                    progress: 0,
                    startedAt: Date(),
                    sceneName: scene.name
                )

                await MainActor.run {
                    self.appState?.addJob(job)
                    self.isGenerating = false
                }
            } catch let error as GenerationClientError {
                NSLog("🎬 ProjectStudioViewModel: Generation failed with GenerationClientError: \(error)")
                await MainActor.run {
                    self.isGenerating = false
                    self.appState?.isLoading = false
                    self.appState?.activeError = error.asAppError
                }
            } catch {
                NSLog("🎬 ProjectStudioViewModel: Generation failed with unexpected error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isGenerating = false
                    self.appState?.isLoading = false
                    self.appState?.activeError = AppError.generationFailed(details: error.localizedDescription) { [weak self] in
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
        AppLogger.shared.info("Using generation: \(generation.id)", category: .ui)
    }

    func regenerateFromSettings(_ generation: SceneGeneration) {
        guard let project = project else { return }

        isGenerating = true

        let modelId = generation.modelProfile?.id ?? (scenes.first(where: { $0.id == generation.sceneId })?.modelProfileId) ?? project.modelProfileId ?? "ltx-video-av-q4"
        let modelName = availableModels.first(where: { $0.id == modelId })?.name ?? generation.modelProfile?.name ?? "LTX Video AV Q4"

        let request = GenerationRequest(
            prompt: generation.composedPrompt,
            negativePrompt: generation.negativePrompt,
            modelId: modelId,
            projectId: project.id,
            sceneId: generation.sceneId,
            composedPrompt: generation.composedPrompt
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
                    modelProfile: ModelProfileSummary(id: modelId, name: modelName),
                    progress: 0,
                    startedAt: Date(),
                    sceneName: selectedScene?.name
                )

                await MainActor.run {
                    self.appState?.addJob(job)
                    self.isGenerating = false
                }
            } catch {
                AppLogger.shared.error("Failed to submit generation job: \(error)", category: .worker)
                await MainActor.run {
                    self.isGenerating = false
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
