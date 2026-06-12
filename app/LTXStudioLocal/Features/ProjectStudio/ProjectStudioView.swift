import SwiftUI

struct ProjectStudioView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectStudioViewModel()
    @State private var editingSceneId: String?
    @State private var newSceneName: String = ""
    @State private var isShowingElementPicker = false
    @State private var selectedElementForDetail: ContinuityElement?
    @State private var isShowingComposedPrompt = false
    @State private var selectedGenerationForPrompt: SceneGeneration?
    @State private var isShowingExportDialog = false

    var body: some View {
        Group {
            if viewModel.project != nil {
                studioContent
            } else {
                emptyState
            }
        }
        .onAppear {
            viewModel.setAppState(appState)
            // Load mock data if nothing is selected for MVP demonstration
            if viewModel.project == nil {
                let mockScene = Scene(name: "Introduction Scene", prompt: "A man walking through a futuristic city", durationSeconds: 5.0, generations: [.mock])
                viewModel.selectProject(.mock, scenes: [mockScene, Scene(name: "Scene 2", prompt: "A robot in a garden")])
            }
        }
        .sheet(isPresented: $isShowingElementPicker) {
            if let sceneId = viewModel.selectedSceneId {
                ContinuityElementPicker { element in
                    viewModel.attachElement(sceneId, elementId: element.id, type: element.type)
                }
            }
        }
        .sheet(item: $selectedElementForDetail) { element in
            elementDetailSheet(element)
        }
        .sheet(isPresented: $isShowingComposedPrompt) {
            if let scene = viewModel.selectedScene {
                composedPromptSheet(scene)
            }
        }
        .sheet(item: $selectedGenerationForPrompt) { generation in
            generationPromptSheet(generation)
        }
        .sheet(isPresented: $isShowingExportDialog) {
            ExportDialog(viewModel: viewModel, isPresented: $isShowingExportDialog)
        }
        .sheet(isPresented: $viewModel.isShowingPromptComparison) {
            if let improved = viewModel.improvedPrompt, let sceneId = viewModel.selectedSceneId {
                promptImprovementSheet(improved, sceneId: sceneId)
            }
        }
    }

    private func promptImprovementSheet(_ improved: ImprovedPrompt, sceneId: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Improve Prompt")
                    .font(.App.headline)
                Spacer()
                Button("Cancel") {
                    viewModel.rejectImprovedPrompt()
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.App.secondaryText)
            }
            .padding()
            .background(Color.App.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("ORIGINAL")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)
                        Text(improved.original)
                            .font(.App.body)
                            .padding(Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                    }

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("IMPROVED")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)

                        TextEditor(text: Binding(
                            get: { viewModel.improvedPrompt?.improved ?? "" },
                            set: { newValue in
                                if let current = viewModel.improvedPrompt {
                                    viewModel.improvedPrompt = ImprovedPrompt(original: current.original, improved: newValue, changes: current.changes)
                                }
                            }
                        ))
                        .font(.App.body)
                        .frame(height: 150)
                        .padding(Spacing.small)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.accent.opacity(0.5)))
                    }

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("ADDED STRUCTURE")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)

                        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                            ForEach(improved.changes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack(alignment: .top) {
                                    Text("\(key):")
                                        .font(.App.caption)
                                        .fontWeight(.bold)
                                        .frame(width: 80, alignment: .leading)
                                    Text(value)
                                        .font(.App.caption)
                                }
                            }
                        }
                        .padding(Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                    }
                }
                .padding(Spacing.large)
            }

            HStack(spacing: Spacing.medium) {
                SecondaryButton("Reject") {
                    viewModel.rejectImprovedPrompt()
                }
                PrimaryButton("Accept & Use") {
                    viewModel.acceptImprovedPrompt(for: sceneId)
                }
            }
            .padding(Spacing.large)
            .background(Color.App.surface)
        }
        .frame(width: 600, height: 600)
    }

    private func generationPromptSheet(_ generation: SceneGeneration) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Generation Prompt")
                    .font(.App.headline)
                Spacer()
                Button("Done") {
                    selectedGenerationForPrompt = nil
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.App.accent)
            }
            .padding()
            .background(Color.App.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("PROMPT")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)
                        Text(generation.composedPrompt)
                            .font(.App.body)
                            .padding(Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                    }

                    if let neg = generation.negativePrompt, !neg.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("NEGATIVE PROMPT")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Text(neg)
                                .font(.App.body)
                                .padding(Spacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                        }
                    }
                }
                .padding(Spacing.large)
            }
        }
        .frame(width: 500, height: 400)
    }

    private func elementDetailSheet(_ element: ContinuityElement) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Element Details")
                    .font(.App.headline)
                Spacer()
                Button("Done") {
                    selectedElementForDetail = nil
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.App.accent)
            }
            .padding()
            .background(Color.App.surface)

            ContinuityElementDetailView(viewModel: ContinuityLibraryViewModel(), element: element)
        }
        .frame(width: 500, height: 600)
    }

    private func composedPromptSheet(_ scene: Scene) -> some View {
        let composed = viewModel.composePrompt(for: scene)

        return VStack(spacing: 0) {
            HStack {
                Text("Composed Prompt")
                    .font(.App.headline)
                Spacer()
                Button("Done") {
                    isShowingComposedPrompt = false
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.App.accent)
            }
            .padding()
            .background(Color.App.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Text("PROMPT")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(composed.prompt, forType: .string)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.App.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Color.App.accent)
                        }

                        Text(composed.prompt)
                            .font(.App.body)
                            .padding(Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                    }

                    if !composed.negativePrompt.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Text("NEGATIVE PROMPT")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(composed.negativePrompt, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.App.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Color.App.accent)
                            }

                            Text(composed.negativePrompt)
                                .font(.App.body)
                                .padding(Spacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.App.border))
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("METADATA")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(composed.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(value)
                                        .foregroundColor(Color.App.secondaryText)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .padding(Spacing.medium)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.App.background))
                    }

                    Text("This is the exact prompt and data that will be sent to the generation worker.")
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                        .italic()
                }
                .padding(Spacing.large)
            }
        }
        .frame(width: 600, height: 700)
    }

    private var studioContent: some View {
        HStack(spacing: 0) {
            sidebar

            VStack(spacing: 0) {
                mainCanvas
                timeline
            }

            inspector
        }
        .background(Color.App.background)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "Project Studio",
            message: "Select or create a project to get started.",
            icon: "video.badge.plus",
            actionTitle: "New Project"
        ) {
            // New Project Action
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCENES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.App.secondaryText)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)

            List {
                ForEach(viewModel.scenes) { scene in
                    SceneSidebarItem(
                        scene: scene,
                        isSelected: viewModel.selectedSceneId == scene.id,
                        isEditing: editingSceneId == scene.id,
                        onSelect: { viewModel.selectedSceneId = scene.id },
                        onRename: { name in
                            viewModel.renameScene(scene.id, newName: name)
                            editingSceneId = nil
                        },
                        onDelete: { viewModel.deleteScene(scene.id) },
                        onDuplicate: { viewModel.duplicateScene(scene.id) },
                        startEditing: {
                            editingSceneId = scene.id
                            newSceneName = scene.name
                        }
                    )
                }
                .onMove(perform: viewModel.moveScene)

                Button(action: viewModel.addScene) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Scene")
                    }
                    .foregroundColor(Color.App.accent)
                }
                .buttonStyle(.plain)
                .padding(.vertical, Spacing.small)
            }
            .listStyle(.sidebar)
        }
        .frame(width: 200)
        .overlay(
            Rectangle()
                .fill(Color.App.border)
                .frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - Main Canvas
    private var mainCanvas: some View {
        ZStack {
            Color.black.opacity(0.05)

            if let scene = viewModel.selectedScene {
                VStack {
                    Text(scene.name)
                        .font(.App.headline)
                        .foregroundColor(Color.App.secondaryText)

                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.App.border)

                    Text("Preview Canvas")
                        .font(.App.subheadline)
                        .foregroundColor(Color.App.secondaryText)

                    if scene.mode != .retake {
                        Button {
                            viewModel.updateSceneMode(scene.id, mode: .retake)
                        } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise.circle")
                                .font(.App.body)
                                .foregroundColor(Color.App.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Spacing.medium)
                    }
                }
            } else {
                Text("Select a scene to preview")
                    .foregroundColor(Color.App.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Timeline
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()

            HStack {
                Text("TIMELINE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.App.secondaryText)

                Spacer()

                if let project = viewModel.project {
                    let totalDuration = viewModel.scenes.reduce(0.0) { $0 + $1.durationSeconds }
                    Text(String(format: "%.1fs", totalDuration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.App.secondaryText)

                    Button {
                        isShowingExportDialog = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.App.accent)
                    .padding(.leading, Spacing.small)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: Spacing.xxSmall) {
                    ForEach(viewModel.scenes) { scene in
                        TimelineClipView(
                            scene: scene,
                            isSelected: viewModel.selectedSceneId == scene.id
                        )
                        .onTapGesture {
                            viewModel.selectedSceneId = scene.id
                        }
                        .contextMenu {
                            Button("Duplicate") {
                                viewModel.duplicateScene(scene.id)
                            }
                            Button("Delete", role: .destructive) {
                                viewModel.deleteScene(scene.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, Spacing.medium)
            }
        }
        .frame(height: 140)
        .background(Color.App.surface)
    }

    // MARK: - Inspector
    private var inspector: some View {
        InspectorPanel(title: "Scene Inspector") {
            if let scene = viewModel.selectedScene {
                InspectorSection(title: "General") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Name")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)

                        TextField("Scene Name", text: Binding(
                            get: { scene.name },
                            set: { viewModel.renameScene(scene.id, newName: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Scene Name")

                        Text("Mode")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)
                            .padding(.top, Spacing.xSmall)

                        Picker("Scene Mode", selection: Binding(
                            get: { scene.mode },
                            set: { viewModel.updateSceneMode(scene.id, mode: $0) }
                        )) {
                            Text("Text to Video").tag(SceneMode.textToVideo)
                            Text("Image to Video").tag(SceneMode.imageToVideo)
                            Text("Audio to Video").tag(SceneMode.audioToVideo)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Generation Mode")
                    }
                }

                InspectorSection(title: "Audio", isCollapsible: true) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Audio Mode")
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)

                        Picker("Audio Mode", selection: Binding(
                            get: { scene.audioMode },
                            set: { viewModel.updateAudioMode(scene.id, mode: $0) }
                        )) {
                            Text("Generate").tag(AudioMode.generate)
                            Text("Mute").tag(AudioMode.mute)
                            Text("Imported").tag(AudioMode.imported)
                            Text("Voiceover").tag(AudioMode.voiceover)
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Audio Generation Mode")

                        if scene.audioMode == .imported || scene.audioMode == .voiceover {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text(scene.audioMode == .imported ? "Imported Audio" : "Voiceover Script/File")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)

                                if let audioPath = scene.audioReferencePath {
                                    HStack {
                                        Image(systemName: "waveform")
                                        Text(URL(fileURLWithPath: audioPath).lastPathComponent)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: { viewModel.updateAudioReference(scene.id, path: nil) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color.App.secondaryText)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(Spacing.small)
                                    .background(Color.App.background)
                                    .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .frame(height: 60)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: "music.note.list")
                                                Text("Drop audio here")
                                                    .font(.App.caption)
                                            }
                                            .foregroundColor(Color.App.secondaryText)
                                        )
                                        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                                            if let provider = providers.first {
                                                provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, error in
                                                    if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                                                        DispatchQueue.main.async {
                                                            viewModel.updateAudioReference(scene.id, path: url.path)
                                                        }
                                                    }
                                                }
                                                return true
                                            }
                                            return false
                                        }
                                }
                            }
                        }

                        // Audio Identity Chips
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Audio Identity")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)

                            let audioElements = scene.attachedContinuityElements.filter { $0.type == .audio }

                            if audioElements.isEmpty {
                                Text("No audio identity attached")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                    .italic()
                            } else {
                                FlowLayout(spacing: 4) {
                                    ForEach(audioElements, id: \.elementId) { attached in
                                        if let element = appState.continuityElements.first(where: { $0.id == attached.elementId }) {
                                            ElementChip(element: element) {
                                                selectedElementForDetail = element
                                            } onRemove: {
                                                viewModel.detachElement(scene.id, elementId: element.id)
                                            }
                                        }
                                    }
                                }
                            }

                            Button(action: { isShowingElementPicker = true }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Identity")
                                }
                                .font(.App.caption)
                                .foregroundColor(Color.App.accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.top, Spacing.small)
                    }
                }

                if scene.mode == .imageToVideo {
                    InspectorSection(title: "Reference Image", isCollapsible: true) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            if let imagePath = scene.referenceImagePath,
                               let image = NSImage(contentsOfFile: imagePath) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .cornerRadius(4)
                                    .overlay(
                                        Button(action: { viewModel.updateReferenceImage(scene.id, path: nil) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.5).clipShape(Circle()))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .frame(height: 120)
                                    .overlay(
                                        VStack(spacing: Spacing.xSmall) {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.system(size: 24))
                                            Text("Drop image here")
                                                .font(.App.caption)
                                        }
                                        .foregroundColor(Color.App.secondaryText)
                                    )
                                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                                        if let provider = providers.first {
                                            provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, error in
                                                if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                                                    DispatchQueue.main.async {
                                                        viewModel.updateReferenceImage(scene.id, path: url.path)
                                                    }
                                                }
                                            }
                                            return true
                                        }
                                        return false
                                    }
                            }
                        }
                    }
                }

                if scene.mode == .retake {
                    InspectorSection(title: "Retake Configuration", isCollapsible: true) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Start (s)")
                                        .font(.App.caption)
                                    TextField("0.0", value: $viewModel.retakeStartSeconds, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading) {
                                    Text("End (s)")
                                        .font(.App.caption)
                                    TextField("5.0", value: $viewModel.retakeEndSeconds, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Text("Retake Prompt")
                                .font(.App.caption)
                            TextEditor(text: $viewModel.retakePrompt)
                                .frame(height: 60)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.App.border))

                            HStack {
                                PrimaryButton("Generate Retake", icon: "sparkles") {
                                    viewModel.generateScene()
                                }
                                .disabled(viewModel.isGenerating)

                                SecondaryButton("Cancel") {
                                    viewModel.updateSceneMode(scene.id, mode: .textToVideo)
                                }
                            }
                        }
                    }
                } else {
                    InspectorSection(title: "Prompt") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        TextEditor(text: Binding(
                            get: { scene.prompt },
                            set: { viewModel.updateScenePrompt(scene.id, prompt: $0) }
                        ))
                        .frame(height: 100)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.App.border))
                        .accessibilityLabel("Scene Prompt")

                        HStack(spacing: Spacing.medium) {
                            Button(action: { viewModel.improvePrompt(for: scene.id) }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Improve Prompt")
                                }
                                .font(.App.caption)
                                .foregroundColor(Color.App.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Enhance your prompt using AI")

                            Button(action: { isShowingComposedPrompt = true }) {
                                HStack {
                                    Image(systemName: "eye")
                                    Text("View Full Prompt")
                                }
                                .font(.App.caption)
                                .foregroundColor(Color.App.accent)
                            }
                            .buttonStyle(.plain)
                            .help("See the final prompt with all elements combined")
                        }
                    }
                }

                InspectorSection(title: "Continuity Elements", isCollapsible: true) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        if scene.attachedContinuityElements.isEmpty {
                            Text("No elements attached")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                                .italic()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.xxSmall) {
                                    ForEach(scene.attachedContinuityElements, id: \.elementId) { element in
                                        ElementChip(element.elementId, icon: element.type.iconName) {
                                            // Open detail
                                            if let found = try? FileContinuityStore().loadAll().first(where: { $0.id == element.elementId }) {
                                                selectedElementForDetail = found
                                            }
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                viewModel.removeElement(scene.id, elementId: element.elementId)
                                            } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button(action: { isShowingElementPicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add reusable element")
                            }
                            .font(.App.caption)
                            .foregroundColor(Color.App.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Attach characters, locations, or styles from your library")
                    }
                }

                InspectorSection(title: "Consistency Locks", isCollapsible: true, isExpanded: false) {
                    VStack(spacing: Spacing.xxSmall) {
                        LockToggle(label: "Character Identity", isOn: Binding(
                            get: { scene.consistencyLocks.character },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.character) }
                        ))
                        LockToggle(label: "Location", isOn: Binding(
                            get: { scene.consistencyLocks.location },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.location) }
                        ))
                        LockToggle(label: "Visual Style", isOn: Binding(
                            get: { scene.consistencyLocks.style },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.style) }
                        ))
                        LockToggle(label: "Brand", isOn: Binding(
                            get: { scene.consistencyLocks.brand },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.brand) }
                        ))
                        LockToggle(label: "Audio Identity", isOn: Binding(
                            get: { scene.consistencyLocks.audio },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.audio) }
                        ))
                    }
                }

                InspectorSection(title: "Advanced Settings", isCollapsible: true, isExpanded: false) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Negative Prompt")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)

                            TextEditor(text: Binding(
                                get: { scene.negativePrompt ?? "" },
                                set: { viewModel.updateSceneNegativePrompt(scene.id, prompt: $0) }
                            ))
                            .frame(height: 60)
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.App.border))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)

                            HStack {
                                Slider(value: Binding(
                                    get: { scene.durationSeconds },
                                    set: { viewModel.updateSceneDuration(scene.id, duration: $0) }
                                ), in: 1...10, step: 0.5)

                                Text("\(String(format: "%.1f", scene.durationSeconds))s")
                                    .font(.App.caption)
                                    .frame(width: 40)
                            }
                        }

                        // Seed
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Seed")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                Spacer()
                                LockToggle(label: "Lock", isOn: Binding(
                                    get: { scene.consistencyLocks.seed },
                                    set: { _ in viewModel.toggleLock(scene.id, keyPath: \.seed) }
                                ))
                                .scaleEffect(0.8)
                            }

                            TextField("Random", value: Binding(
                                get: { scene.seed },
                                set: { viewModel.updateSceneAdvancedSettings(scene.id, seed: $0) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                        }

                        // Inference Steps
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Inference Steps")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            HStack {
                                Slider(value: Binding(
                                    get: { Float(scene.inferenceSteps ?? 30) },
                                    set: { viewModel.updateSceneAdvancedSettings(scene.id, inferenceSteps: Int($0)) }
                                ), in: 1...100, step: 1)
                                Text("\(scene.inferenceSteps ?? 30)")
                                    .font(.App.caption)
                                    .frame(width: 30)
                            }
                        }

                        // Guidance Scale
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Guidance Scale")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            HStack {
                                Slider(value: Binding(
                                    get: { scene.guidanceScale ?? 7.5 },
                                    set: { viewModel.updateSceneAdvancedSettings(scene.id, guidanceScale: $0) }
                                ), in: 1...20, step: 0.5)
                                Text("\(String(format: "%.1f", scene.guidanceScale ?? 7.5))")
                                    .font(.App.caption)
                                    .frame(width: 30)
                            }
                        }

                        // FPS & Frame Count
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FPS")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                TextField("24", value: Binding(
                                    get: { scene.fps },
                                    set: { viewModel.updateSceneAdvancedSettings(scene.id, fps: $0) }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Frames")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                TextField("120", value: Binding(
                                    get: { scene.frameCount },
                                    set: { viewModel.updateSceneAdvancedSettings(scene.id, frameCount: $0) }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Model Profile
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Profile")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Picker("Model Profile", selection: Binding(
                                get: { scene.modelProfileId ?? "default" },
                                set: { viewModel.updateSceneAdvancedSettings(scene.id, modelProfileId: $0) }
                            )) {
                                Text("Recommended Default").tag("default")
                                ForEach(viewModel.availableModels) { model in
                                    Text(model.name).tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // LoRA Placeholder
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LoRA Weights")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Text("No LoRAs attached")
                                .font(.App.footnote)
                                .foregroundColor(Color.App.secondaryText)
                                .padding(Spacing.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.App.background)
                                .cornerRadius(4)
                        }

                        // Upscaler Placeholder
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upscaler")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Picker("Upscaler", selection: .constant("none")) {
                                Text("None").tag("none")
                                Text("Spatial 2x (Placeholder)").tag("spatial2x")
                                Text("Temporal 2x (Placeholder)").tag("temporal2x")
                            }
                            .pickerStyle(.menu)
                            .disabled(true)
                        }

                        // Quantization Placeholder
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantization Mode")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
                            Picker("Quantization", selection: .constant("auto")) {
                                Text("Auto (Recommended)").tag("auto")
                                Text("4-bit (Placeholder)").tag("4bit")
                                Text("8-bit (Placeholder)").tag("8bit")
                            }
                            .pickerStyle(.menu)
                            .disabled(true)
                        }

                        Button("Reset to Recommended Defaults") {
                            viewModel.resetSceneAdvancedSettings(scene.id)
                        }
                        .buttonStyle(.link)
                        .font(.App.caption)
                        .padding(.top, 4)
                    }
                }

                InspectorSection(title: "History", isCollapsible: true, isExpanded: false) {
                    SceneHistoryView(
                        generations: scene.generations,
                        onUse: { viewModel.useGeneration($0) },
                        onViewPrompt: { selectedGenerationForPrompt = $0 },
                        onDelete: { viewModel.deleteGeneration($0.id) },
                        onRegenerate: { viewModel.regenerateFromSettings($0) }
                    )
                }

                Spacer()

                PrimaryButton("Generate Scene", icon: "sparkles") {
                    viewModel.generateScene()
                }
                .padding(.bottom, Spacing.medium)
            } else {
                Text("Select a scene to edit its properties")
                    .foregroundColor(Color.App.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.xxLarge)
            }
        }
    }
}

// MARK: - Helper Views

struct SceneSidebarItem: View {
    let scene: Scene
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let startEditing: () -> Void

    @State private var nameText: String = ""

    var body: some View {
        HStack {
            if isEditing {
                TextField("", text: $nameText, onCommit: {
                    onRename(nameText)
                })
                .textFieldStyle(.plain)
                .onAppear { nameText = scene.name }
            } else {
                Text(scene.name)
                    .font(.App.body)

                Spacer()

                if isSelected {
                    Menu {
                        Button("Rename", action: startEditing)
                        Button("Duplicate", action: onDuplicate)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color.App.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .listRowBackground(isSelected ? Color.App.accent.opacity(0.1) : Color.clear)
    }
}

struct TimelineClipView: View {
    let scene: Scene
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.App.accent.opacity(0.1) : Color.App.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.App.accent : Color.App.border, lineWidth: isSelected ? 2 : 1)
                    )
                    .frame(width: 140, height: 80)

                Text(String(format: "%.1fs", scene.durationSeconds))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(2)
                    .padding(4)
            }
            .overlay(
                Image(systemName: "video.fill")
                    .foregroundColor(Color.App.secondaryText.opacity(0.3))
            )

            Text(scene.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
    }
}

struct LockToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.App.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}


extension ContinuityElementType {
    var iconName: String {
        switch self {
        case .character: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .style: return "paintpalette.fill"
        case .camera: return "video.fill"
        case .audio: return "waveform"
        case .brand: return "tag.fill"
        case .promptBlock: return "text.alignleft"
        case .lora: return "cpu"
        case .exportTemplate: return "square.and.arrow.up"
        }
    }
}

struct ProjectStudioView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectStudioView()
    }
}
