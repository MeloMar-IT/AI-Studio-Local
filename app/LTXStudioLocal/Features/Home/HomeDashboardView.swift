import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var appState: AppState

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
                                ActionCard(title: "Text to Video", icon: "text.quote", color: .purple)
                                ActionCard(title: "Animate Image", icon: "photo.fill", color: .blue)
                                ActionCard(title: "Audio to Video", icon: "waveform", color: .green)
                                ActionCard(title: "Retake Video", icon: "arrow.counterclockwise.circle.fill", color: .orange)
                                ActionCard(title: "Multi-Scene Story", icon: "film.stack", color: .red)
                                ActionCard(title: "Reusable Elements", icon: "person.2.fill", color: .teal)
                                ActionCard(title: "Local Models", icon: "cpu", color: .gray)
                            }
                        }

                        // 3. Recent Projects Section
                        VStack(alignment: .leading, spacing: Spacing.medium) {
                            Text("Recent Projects")
                                .font(.App.headline)

                            EmptyStateView(
                                title: "No Recent Projects",
                                message: "Your recently edited projects will appear here.",
                                icon: "clock"
                            )
                            .frame(height: 160)
                            .background(Color.App.surface)
                            .cornerRadius(Spacing.cornerRadiusLarge)
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                                    .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
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
                                    value: appState.isWorkerAvailable ? "Online (\(appState.workerVersion))" : "Offline",
                                    status: appState.isWorkerAvailable ? .success : .error
                                )

                                if !appState.isWorkerAvailable {
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
    }
}

// MARK: - Components

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
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

struct HomeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HomeDashboardView()
            .frame(width: 1000, height: 800)
    }
}
