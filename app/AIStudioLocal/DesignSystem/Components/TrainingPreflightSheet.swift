import SwiftUI

/// Popup shown after the user taps "Train LoRA"/"Retrain" and before any
/// training job is actually submitted to the worker. Presents the 0-100
/// dataset quality score and findings from POST /train/lora/preflight
/// (see worker/ai_video_worker/engine/dataset_preflight.py) and gates
/// whether training proceeds behind an explicit Continue/Stop choice.
struct TrainingPreflightSheet: View {
    let presentation: TrainingPreflightPresentation
    let onContinue: () -> Void
    let onStop: () -> Void

    private var result: TrainingPreflightResponse { presentation.result }

    private var scoreColor: Color {
        switch result.score {
        case 85...100: return Color.App.success
        case 60..<85: return Color.App.warning
        default: return Color.App.error
        }
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: Spacing.xxSmall) {
                Text("Training Data Check")
                    .font(.App.title2)
                Text(presentation.element.name)
                    .font(.App.subheadline)
                    .foregroundColor(Color.App.secondaryText)
            }

            ZStack {
                Circle()
                    .stroke(Color.App.border, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(result.score) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(result.score)")
                        .font(.App.title1)
                        .foregroundColor(scoreColor)
                    Text("/ 100")
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }
            }
            .frame(width: 100, height: 100)

            VStack(spacing: Spacing.xxSmall) {
                Text(result.recommendation)
                    .font(.App.body)
                    .multilineTextAlignment(.center)
                Text("\(result.validImageCount) of \(result.imageCount) image(s) usable")
                    .font(.App.caption)
                    .foregroundColor(Color.App.secondaryText)
            }

            if !result.findings.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach(result.findings) { finding in
                            findingRow(finding)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            HStack(spacing: Spacing.small) {
                SecondaryButton("Stop", icon: "xmark", isDestructive: result.score < 60) {
                    onStop()
                }
                PrimaryButton(result.score < 60 ? "Continue Anyway" : "Continue", icon: "arrow.right") {
                    onContinue()
                }
            }
        }
        .padding(Spacing.large)
        .frame(width: 420)
    }

    @ViewBuilder
    private func findingRow(_ finding: PreflightFinding) -> some View {
        HStack(alignment: .top, spacing: Spacing.xSmall) {
            Image(systemName: icon(for: finding.severity))
                .foregroundColor(color(for: finding.severity))
                .frame(width: 16)
            Text(finding.message)
                .font(.App.callout)
                .foregroundColor(Color.App.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.small)
        .background(color(for: finding.severity).opacity(0.08))
        .cornerRadius(Spacing.cornerRadius)
    }

    private func icon(for severity: String) -> String {
        switch severity {
        case "critical": return "exclamationmark.triangle.fill"
        case "warning": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func color(for severity: String) -> Color {
        switch severity {
        case "critical": return Color.App.error
        case "warning": return Color.App.warning
        default: return Color.App.info
        }
    }
}
