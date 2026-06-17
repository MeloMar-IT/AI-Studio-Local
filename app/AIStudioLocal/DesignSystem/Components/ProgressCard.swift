import SwiftUI

struct ProgressCard: View {
    let title: String
    let subtitle: String
    let progress: Double // 0.0 to 1.0
    let status: String
    var startedAt: Date?
    var completedAt: Date?
    var errorInformation: JobErrorInformation?
    var jobStatus: JobStatus = .queued

    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    var onOpenScene: (() -> Void)?

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if let completed = completedAt {
            return "Completed at \(formatter.string(from: completed))"
        } else if let started = startedAt {
            return "Started at \(formatter.string(from: started))"
        }
        return ""
    }

    private var statusColor: Color {
        switch jobStatus {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        case .queued: return .blue
        default: return Color.App.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    HStack(spacing: Spacing.small) {
                        Text(title)
                            .font(.App.headline)

                        StatusBadge(label: jobStatus.rawValue.replacingOccurrences(of: "_", with: " "), color: statusColor)
                    }

                    Text(subtitle)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }

                Spacer()

                if jobStatus != .completed && jobStatus != .failed && jobStatus != .cancelled {
                    Text("\(Int(progress * 100))%")
                        .font(.App.headline)
                        .foregroundColor(Color.App.accent)
                }
            }

            if jobStatus != .completed && jobStatus != .failed && jobStatus != .cancelled {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color.App.accent)
            }

            if let error = errorInformation {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(error.message)
                        .font(.App.footnote)
                        .foregroundColor(Color.App.error)

                    if let suggestion = error.suggestedAction {
                        Text(suggestion)
                            .font(.App.caption)
                            .foregroundColor(Color.App.secondaryText)
                    }
                }
                .padding(Spacing.small)
                .background(Color.App.error.opacity(0.1))
                .cornerRadius(Spacing.cornerRadius)
            }

            HStack {
                HStack(spacing: Spacing.xSmall) {
                    Image(systemName: jobStatus == .completed ? "checkmark.circle" : (jobStatus == .failed ? "exclamationmark.triangle" : "gearshape.2"))
                        .font(.App.footnote)
                        .foregroundColor(Color.App.secondaryText)
                    Text(status)
                        .font(.App.footnote)
                        .foregroundColor(Color.App.secondaryText)
                }

                Spacer()

                Text(timeString)
                    .font(.App.caption)
                    .foregroundColor(Color.App.secondaryText.opacity(0.7))
            }

            Divider()
                .padding(.vertical, Spacing.xxSmall)

            HStack(spacing: Spacing.medium) {
                if onOpenScene != nil {
                    Button(action: { onOpenScene?() }) {
                        Label("Open Scene", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.App.footnote)
                    .foregroundColor(Color.App.accent)
                }

                Spacer()

                if jobStatus == .failed, let onRetry = onRetry {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .font(.App.footnote)
                    .foregroundColor(Color.App.accent)
                }

                if (jobStatus != .completed && jobStatus != .failed && jobStatus != .cancelled), let onCancel = onCancel {
                    Button(action: onCancel) {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.App.footnote)
                    .foregroundColor(Color.App.error)
                }
            }
        }
        .padding(Spacing.medium)
        .background(Color.App.surface)
        .cornerRadius(Spacing.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .stroke(Color.App.border, lineWidth: 1)
        )
    }
}

struct ProgressCard_Previews: PreviewProvider {
    static var previews: some View {
        ProgressCard(
            title: "Generating Scene 1",
            subtitle: "Cyberpunk City",
            progress: 0.45,
            status: "Generating video frames...",
            jobStatus: .generatingVideo
        )
        .padding()
        .frame(width: 400)
    }
}
