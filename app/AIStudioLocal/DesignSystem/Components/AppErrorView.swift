import SwiftUI

struct AppErrorView: View {
    let error: AppError
    let onDismiss: () -> Void

    @State private var showTechnicalDetails = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.title)

                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(error.title)
                        .font(.App.headline)
                    Text(error.message)
                        .font(.App.subheadline)
                        .foregroundColor(Color.App.secondaryText)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color.App.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.medium)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    // Suggested Actions
                    if !error.suggestedActions.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("SUGGESTED ACTIONS")
                                .font(.App.caption)
                                .foregroundColor(Color.App.secondaryText)

                            ForEach(error.suggestedActions, id: \.self) { action in
                                HStack(alignment: .top, spacing: Spacing.xSmall) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(Color.App.accent.opacity(0.7))
                                        .font(.caption)
                                        .padding(.top, 2)
                                    Text(action)
                                        .font(.App.body)
                                }
                            }
                        }
                    }

                    // Technical Details Disclosure
                    if let details = error.technicalDetails {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Button(action: { showTechnicalDetails.toggle() }) {
                                HStack {
                                    Text("TECHNICAL DETAILS")
                                        .font(.App.caption)
                                    Image(systemName: showTechnicalDetails ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(Color.App.secondaryText)
                            }
                            .buttonStyle(.plain)

                            if showTechnicalDetails {
                                Text(details)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(Spacing.small)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(Spacing.medium)
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer
            HStack(spacing: Spacing.medium) {
                Spacer()

                SecondaryButton("Dismiss", action: onDismiss)

                if let retry = error.retryAction {
                    PrimaryButton("Retry") {
                        onDismiss()
                        retry()
                    }
                }
            }
            .padding(Spacing.medium)
            .background(Color.App.background.opacity(0.5))
        }
        .background(Color.App.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 450)
        .shadow(radius: 20)
    }
}

struct AppErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            AppErrorView(
                error: AppError.insufficientMemory(),
                onDismiss: {}
            )
        }
    }
}
