import SwiftUI

struct RenderQueueView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack {
                    Text("Render Queue")
                        .font(.App.largeTitle)

                    Spacer()

                    if !appState.activeJobs.isEmpty {
                        Button(action: { appState.clearCompletedJobs() }) {
                            Label("Clear Finished", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color.App.secondaryText)
                    }
                }
                .padding(.bottom, Spacing.small)

                if appState.activeJobs.isEmpty {
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
        VStack(spacing: Spacing.medium) {
            Spacer(minLength: 100)
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 80))
                .foregroundColor(Color.App.secondaryText.opacity(0.3))

            Text("No active or completed jobs")
                .font(.App.headline)
                .foregroundColor(Color.App.secondaryText)

            Text("When you generate scenes, they will appear here.")
                .font(.App.body)
                .foregroundColor(Color.App.secondaryText.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var jobsList: some View {
        VStack(spacing: Spacing.medium) {
            ForEach(appState.activeJobs.reversed()) { job in
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
                        appState.cancelJob(job)
                    },
                    onRetry: {
                        // In a real app, this would trigger a new generation in ProjectStudioViewModel
                        // For MVP, we can just print or show an alert
                        print("Retry job \(job.id)")
                    },
                    onOpenScene: {
                        router.selectedProjectID = job.projectId
                        router.selectedScreen = .projectStudio
                        // We might need a way to pass the selected scene to the ProjectStudioView
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
