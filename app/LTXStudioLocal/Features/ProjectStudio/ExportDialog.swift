import SwiftUI

struct ExportDialog: View {
    @ObservedObject var viewModel: ProjectStudioViewModel
    @Binding var isPresented: Bool

    @State private var selectedPreset: ExportPreset = .youtube
    @State private var showSuccessMessage = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Project")
                    .font(.App.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color.App.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.App.surface)

            if viewModel.isExporting {
                exportingView
            } else if showSuccessMessage {
                successView
            } else {
                presetSelectionView
            }
        }
        .frame(width: 500, height: 400)
        .background(Color.App.background)
        .cornerRadius(Spacing.cornerRadius)
        .shadow(radius: 20)
        .onChange(of: viewModel.isExporting) { isExporting in
            if !isExporting && viewModel.lastExport != nil {
                showSuccessMessage = true
            }
        }
    }

    private var presetSelectionView: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Select an export preset for your video.")
                .font(.App.body)
                .foregroundColor(Color.App.secondaryText)

            ScrollView {
                VStack(spacing: Spacing.medium) {
                    ForEach(ExportPreset.allPresets) { preset in
                        PresetRow(
                            preset: preset,
                            isSelected: selectedPreset.id == preset.id,
                            action: { selectedPreset = preset }
                        )
                    }
                }
            }

            Spacer()

            HStack {
                SecondaryButton("Cancel") {
                    isPresented = false
                }
                Spacer()
                PrimaryButton("Export Now", icon: "square.and.arrow.up") {
                    startExport()
                }
                .disabled(viewModel.scenes.isEmpty)
            }
        }
        .padding(Spacing.large)
    }

    private var exportingView: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Exporting project...")
                .font(.App.headline)
            Text("Applying brand overlays and encoding video.")
                .font(.App.body)
                .foregroundColor(Color.App.secondaryText)
            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: Spacing.small) {
                Text("Export Completed")
                    .font(.App.headline)
                if let lastExport = viewModel.lastExport {
                    Text("Saved to: \(lastExport.outputPath)")
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }
            }

            Spacer()

            PrimaryButton("Close") {
                isPresented = false
            }
        }
        .padding(Spacing.large)
    }

    private func startExport() {
        // In a real app we'd need the actual project URL.
        // For MVP, we use a mock URL or let the ViewModel handle it.
        let projectURL = URL(fileURLWithPath: "/tmp/LTXProjects/MockProject.ltxproject")
        viewModel.exportProject(preset: selectedPreset, projectURL: projectURL)

        // Watch for completion to show success view
        // In a more robust implementation, this would be handled better by the ViewModel
    }
}

private struct PresetRow: View {
    let preset: ExportPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.App.headline)
                        .foregroundColor(isSelected ? Color.App.accent : Color.App.text)
                    Text(preset.description)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(label: preset.format.rawValue, color: Color.App.accent)
                    Text("\(preset.width)x\(preset.height)")
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color.App.accent : Color.App.border)
            }
            .padding(Spacing.medium)
            .background(Color.App.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.App.accent : Color.App.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
