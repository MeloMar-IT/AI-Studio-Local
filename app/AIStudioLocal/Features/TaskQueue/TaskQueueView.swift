import SwiftUI

struct TaskQueueView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TaskQueueContentView(viewModel: TaskQueueViewModel(appState: appState), router: router)
    }
}

struct TaskQueueContentView: View {
    @StateObject var viewModel: TaskQueueViewModel
    let router: AppRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack {
                    Text("Task Queue")
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
                    subtitle: subtitleForJob(job),
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
                        if job.mode != .modelDownload {
                            router.selectedProjectID = job.projectId
                            router.selectedScreen = .projectStudio
                            NotificationCenter.default.post(name: .selectScene, object: job.sceneId)
                        } else {
                            router.selectedScreen = .modelManager
                        }
                    }
                )
            }
        }
    }

    private func subtitleForJob(_ job: GenerationJob) -> String {
        if job.mode == .modelDownload {
            return "Model Download"
        } else {
            return "\(job.mode.rawValue.capitalized) • \(job.modelProfile?.name ?? "Default Model")"
        }
    }
}

extension NSNotification.Name {
    static let selectScene = NSNotification.Name("selectScene")
}
