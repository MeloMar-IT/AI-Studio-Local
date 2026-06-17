import SwiftUI

struct RenderQueueView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        RenderQueueContentView(viewModel: RenderQueueViewModel(appState: appState), router: router)
    }
}

struct RenderQueueContentView: View {
    @StateObject var viewModel: RenderQueueViewModel
    let router: AppRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack {
                    Text("Render Queue")
                        .font(.App.largeTitle)

                    Spacer()

                    if !viewModel.jobs.isEmpty {
                        Button(action: { viewModel.clearCompletedJobs() }) {
                            Label("Clear Finished", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color.App.secondaryText)
                    }
                }
                .padding(.bottom, Spacing.small)

                if viewModel.jobs.isEmpty {
                    emptyState
                } else {
                    jobsList
                }
            }
            .padding(Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No active or completed jobs",
            message: "When you generate scenes, they will appear here.",
            icon: "tray.and.arrow.down",
            actionTitle: "Create First Scene",
            action: {
                router.selectedScreen = .projectStudio
            }
        )
        .frame(minHeight: 400)
    }

    private var jobsList: some View {
        VStack(spacing: Spacing.medium) {
            ForEach(viewModel.jobs) { job in
                ProgressCard(
                    title: job.sceneName ?? "Scene \(job.sceneId)",
                    subtitle: "\(job.mode.rawValue.capitalized) • \(job.modelProfile?.name ?? "Default Model")",
                    progress: job.progress,
                    status: job.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    startedAt: job.startedAt,
                    completedAt: job.completedAt,
                    errorInformation: job.errorInformation,
                    jobStatus: job.status,
                    onCancel: {
                        viewModel.cancelJob(job)
                    },
                    onRetry: {
                        // In a real app, this would trigger a new generation in ProjectStudioViewModel
                        AppLogger.shared.info("Retrying job \(job.id)", category: .worker)
                    },
                    onOpenScene: {
                        router.selectedProjectID = job.projectId
                        router.selectedScreen = .projectStudio
                        NotificationCenter.default.post(name: .selectScene, object: job.sceneId)
                    }
                )
            }
        }
    }
}

extension NSNotification.Name {
    static let selectScene = NSNotification.Name("selectScene")
}
