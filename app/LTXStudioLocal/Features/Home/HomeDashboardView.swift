import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeDashboardViewModel()
    @State private var isShowingTemplateSelection = false
    @State private var isShowingLogViewer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxxLarge) {
                // 1. Welcome Area
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("What do you want to make today?")
                        .font(.App.largeTitle)
                    Text("Select a tool below to start creating.")
                        .font(.App.subtitle)
                        .foregroundColor(Color.App.secondaryText)
                }

                HStack(alignment: .top, spacing: Spacing.xxxLarge) {
                    VStack(alignment: .leading, spacing: Spacing.xxxLarge) {
                        // 2. Create Action Cards Grid
                        VStack(alignment: .leading, spacing: Spacing.medium) {
                            Text("Quick Actions")
                                .font(.App.headline)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: Spacing.medium)
                            ], spacing: Spacing.medium) {
                                ActionCard(title: "Multi-Scene Story", icon: "film.stack", color: .red) {
                                    isShowingTemplateSelection = true
                                }
                                ActionCard(title: "Text to Video", icon: "text.quote", color: .purple) {
                                    createQuickProject(mode: .textToVideo)
                                }
                                ActionCard(title: "Animate Image", icon: "photo.fill", color: .blue) {
                                    createQuickProject(mode: .imageToVideo)
                                }
                                ActionCard(title: "Audio to Video", icon: "waveform", color: .green) {
                                    createQuickProject(mode: .audioToVideo)
                                }
                                ActionCard(title: "Retake Video", icon: "arrow.counterclockwise.circle.fill", color: .orange)
                                ActionCard(title: "Reusable Elements", icon: "person.2.fill", color: .teal) {
                                    router.selectedScreen = .continuityLibrary
                                }
                                ActionCard(title: "Local Models", icon: "cpu", color: .gray) {
                                    router.selectedScreen = .modelManager
                                }
                            }
                        }

                        // 3. Recent Projects Section
                        VStack(alignment: .leading, spacing: Spacing.medium) {
                            HStack {
                                Text("Recent Projects")
                                    .font(.App.headline)
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                }
                            }

                            if viewModel.recentProjects.isEmpty {
                                EmptyStateView(
                                    title: "No Recent Projects",
                                    message: "Your recently edited projects will appear here.",
                                    icon: "clock",
                                    actionTitle: "Create New Project",
                                    action: {
                                        isShowingTemplateSelection = true
                                    }
                                )
                                .frame(height: 280)
                                .background(Color.App.surface)
                                .cornerRadius(Spacing.cornerRadiusLarge)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                                        .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                )
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 280, maximum: 350), spacing: Spacing.medium)
                                ], spacing: Spacing.medium) {
                                    ForEach(viewModel.recentProjects) { project in
                                        ProjectCard(project: project) {
                                            openProject(project)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Sidebar for Status Cards
                    VStack(spacing: Spacing.large) {
                        // 4. System Status Card
                        StatusCard(title: "System Status", icon: "desktopcomputer") {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                StatusItem(
                                    label: "Hardware",
                                    value: appState.hardwareProfile.modelName,
                                    status: appState.hardwareProfile.isAppleSilicon ? .success : .warning
                                )
                                StatusItem(
                                    label: "Memory",
                                    value: "\(appState.hardwareProfile.totalMemoryGB)GB Unified",
                                    status: appState.hardwareProfile.totalMemoryGB >= 32 ? .success : .warning
                                )
                                StatusItem(
                                    label: "Worker",
                                    value: appState.isWorkerAvailable ? "Online (\(appState.workerVersion))" : (appState.workerStatus == .starting ? "Starting..." : "Offline"),
                                    status: appState.isWorkerAvailable ? .success : (appState.workerStatus == .starting ? .warning : .error)
                                )

                                if !appState.isWorkerAvailable {
                                    VStack(alignment: .leading, spacing: Spacing.small) {
                                        if appState.workerStatus == .stopped || appState.workerStatus == .failed {
                                            Button(action: {
                                                Task {
                                                    await appState.startWorker()
                                                }
                                            }) {
                                                Label("Start Worker", systemImage: "play.fill")
                                                    .font(.App.caption)
                                                    .foregroundColor(Color.App.accent)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        Button(action: {
                                            Task {
                                                await appState.checkWorkerHealth()
                                            }
                                        }) {
                                            Label("Retry Connection", systemImage: "arrow.clockwise")
                                                .font(.App.caption)
                                                .foregroundColor(Color.App.accent)
                                        }
                                        .buttonStyle(.plain)

                                        Button(action: {
                                            // Open setup instructions URL or local file
                                            if let url = URL(string: "https://github.com/your-repo/ai-studio-local/blob/main/docs/development-setup.md") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }) {
                                            Label("Setup Instructions", systemImage: "questionmark.circle")
                                                .font(.App.caption)
                                                .foregroundColor(Color.App.secondaryText)
                                        }
                                        .buttonStyle(.plain)

                                        if !appState.workerLogs.isEmpty {
                                            Button(action: {
                                                // We'll implement a log viewer sheet or similar
                                                isShowingLogViewer = true
                                            }) {
                                                Label("View Logs", systemImage: "doc.text")
                                                    .font(.App.caption)
                                                    .foregroundColor(Color.App.secondaryText)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, Spacing.xxSmall)
                                }
                            }
                        }

                        // 5. Installed Model Card
                        StatusCard(title: "Installed Models", icon: "brain.head.profile") {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                StatusItem(label: "LTX Video v1", value: "Ready", status: .success)
                                StatusItem(label: "Fast Draft", value: "Ready", status: .success)
                                StatusItem(label: "Upscaler", value: "Not Downloaded", status: .warning)
                            }
                        }

                        // 6. Render Queue Summary
                        StatusCard(title: "Render Queue", icon: "list.bullet.rectangle.stack") {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                StatusItem(label: "Active Jobs", value: "\(appState.activeJobsCount)", status: .info)
                                StatusItem(label: "Waiting", value: "0", status: .info)

                                if appState.activeJobsCount == 0 {
                                    Text("No pending renders.")
                                        .font(.App.caption)
                                        .foregroundColor(Color.App.secondaryText)
                                        .padding(.top, Spacing.xxSmall)
                                } else {
                                    Text("\(appState.activeJobsCount) scenes generating...")
                                        .font(.App.caption)
                                        .foregroundColor(Color.App.accent)
                                        .padding(.top, Spacing.xxSmall)
                                }
                            }
                        }
                    }
                    .frame(width: 260)
                }

                // 7. Local Privacy Message
                HStack {
                    Spacer()
                    HStack(spacing: Spacing.xSmall) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Local Mode: Your prompts, images, audio and generated videos stay on this Mac.")
                            .font(.App.footnote)
                            .foregroundColor(Color.App.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, Spacing.large)
            }
            .padding(Spacing.xxxLarge)
        }
        .background(Color.App.background)
        .sheet(isPresented: $isShowingTemplateSelection) {
            ProjectTemplateSelectionView { template, name, useBrandKit in
                createProjectFromTemplate(template, name: name, useBrandKit: useBrandKit)
            }
        }
        .sheet(isPresented: $isShowingLogViewer) {
            WorkerLogView(logs: appState.workerLogs)
        }
    }

    private func createQuickProject(mode: SceneMode) {
        let name = "New \(mode.rawValue.capitalized) Project"
        let project = Project(name: name)
        let scene = Scene(name: "Scene 1", mode: mode)

        saveAndOpenProject(project, scenes: [scene])
    }

    private func createProjectFromTemplate(_ template: ProjectTemplate, name: String, useBrandKit: Bool) {
        var defaultBrandKitId: String? = nil
        if useBrandKit {
            // In a real app, we'd fetch the default brand kit from ContinuityStore
            // For now, we'll use a placeholder or the mock if available
            defaultBrandKitId = "default-brand-kit"
        }

        var project = Project(
            name: name,
            defaultBrandKitId: defaultBrandKitId,
            aspectRatio: template.aspectRatio
        )

        var scenes: [Scene] = []
        var clips: [TimelineClip] = []
        var currentTime: Double = 0

        for structure in template.sceneStructures {
            let scene = Scene(
                name: structure.name,
                prompt: structure.defaultPrompt,
                durationSeconds: 5.0,
                aspectRatio: template.aspectRatio
            )
            scenes.append(scene)

            let clip = TimelineClip(sceneId: scene.id, startTime: currentTime, duration: 5.0)
            clips.append(clip)
            currentTime += 5.0
        }

        project.scenes = scenes.map { $0.id }
        project.timeline = Timeline(clips: clips)

        saveAndOpenProject(project, scenes: [scenes.isEmpty ? [Scene(name: "Scene 1")] : scenes].first!)
    }

    private func saveAndOpenProject(_ project: Project, scenes: [Scene]) {
        let store = FileProjectStore()
        let projectURL = UserSettings.shared.projectsURL.appendingPathComponent("\(project.id).ltxproject")

        do {
            try store.save(project: project, scenes: scenes, to: projectURL)

            // Navigate to Project Studio
            // In a real app, we might want to pass the project to AppRouter
            router.selectedProjectID = project.id
            router.selectedScreen = .projectStudio

            // Post notification for ProjectStudioViewModel to load this project
            NotificationCenter.default.post(name: .openProject, object: (project, scenes))
        } catch {
            appState.activeError = AppError.projectSaveFailed(error: error)
        }
    }
}

extension NSNotification.Name {
    static let openProject = NSNotification.Name("openProject")
}

// MARK: - Components

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)

                Text(title)
                    .font(.App.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.App.surface)
            .cornerRadius(Spacing.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .stroke(Color.App.border, lineWidth: 1)
            )
            .shadow(color: Color.App.shadow, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct StatusCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: icon)
                    .foregroundColor(Color.App.accent)
                Text(title)
                    .font(.App.headline)
            }

            content
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.App.surface)
        .cornerRadius(Spacing.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .stroke(Color.App.border, lineWidth: 1)
        )
    }
}

struct StatusItem: View {
    let label: String
    let value: String
    let status: StatusType

    enum StatusType {
        case success, warning, error, info

        var color: Color {
            switch self {
            case .success: return Color.App.success
            case .warning: return Color.App.warning
            case .error: return Color.App.error
            case .info: return Color.App.info
            }
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.App.caption)
                .foregroundColor(Color.App.secondaryText)
            Spacer()
            Text(value)
                .font(.App.caption)
                .fontWeight(.bold)
                .foregroundColor(status.color)
        }
    }
}

struct WorkerLogView: View {
    let logs: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Worker Logs")
                    .font(.App.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.App.surface)

            Divider()

            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct HomeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HomeDashboardView()
            .frame(width: 1000, height: 800)
    }
}
