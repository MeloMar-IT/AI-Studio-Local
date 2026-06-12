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
                timelinePlaceholder
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
                        startEditing: {
                            editingSceneId = scene.id
                            newSceneName = scene.name
                        }
                    )
                }

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
                }
            } else {
                Text("Select a scene to preview")
                    .foregroundColor(Color.App.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Timeline
    private var timelinePlaceholder: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Divider()

            Text("TIMELINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.App.secondaryText)
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.small)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) {
                    ForEach(viewModel.scenes) { scene in
                        TimelineClipView(scene: scene, isSelected: viewModel.selectedSceneId == scene.id)
                            .onTapGesture {
                                viewModel.selectedSceneId = scene.id
                            }
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, Spacing.medium)
            }
        }
        .frame(height: 120)
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
                    }
                }

                InspectorSection(title: "Prompt") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        TextEditor(text: Binding(
                            get: { scene.prompt },
                            set: { viewModel.updateScenePrompt(scene.id, prompt: $0) }
                        ))
                        .frame(height: 100)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.App.border))

                        Button(action: { isShowingComposedPrompt = true }) {
                            HStack {
                                Image(systemName: "eye")
                                Text("View Composed Prompt")
                            }
                            .font(.App.caption)
                            .foregroundColor(Color.App.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                InspectorSection(title: "Continuity Elements") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        if scene.attachedContinuityElements.isEmpty {
                            Text("No elements attached")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)
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
                    }
                }

                InspectorSection(title: "Consistency Locks") {
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
                        LockToggle(label: "Seed", isOn: Binding(
                            get: { scene.consistencyLocks.seed },
                            set: { _ in viewModel.toggleLock(scene.id, keyPath: \.seed) }
                        ))
                    }
                }

                InspectorSection(title: "History") {
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
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.App.accent.opacity(0.2) : Color.App.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.App.accent : Color.App.border, lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: 120, height: 60)
                .overlay(
                    Image(systemName: "video.fill")
                        .foregroundColor(Color.App.secondaryText.opacity(0.5))
                )

            Text(scene.name)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
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
