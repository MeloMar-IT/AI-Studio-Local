import SwiftUI

struct RenderQueueView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text("Render Queue")
                    .font(.App.largeTitle)
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
                    title: "Scene \(job.sceneId)", // Ideally we'd have the scene name here
                    subtitle: job.mode.rawValue.capitalized,
                    progress: job.progress,
                    status: job.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
                )
            }
        }
    }
}
