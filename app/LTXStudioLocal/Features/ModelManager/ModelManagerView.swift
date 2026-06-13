import SwiftUI

struct ModelManagerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ModelManagerViewModel(modelStore: RemoteModelStore())
    @State private var showImportPicker = false
    @State private var selectedImportPath: String?
    @State private var showImportDialog = false
    @State private var shouldCopy = true

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Models")
                        .font(.App.title3)

                    Spacer()

                    SecondaryButton("Import", icon: "plus") {
                        showImportPicker = true
                    }
                    .controlSize(.small)
                }
                .padding()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.models, selection: Binding(
                        get: { viewModel.selectedModel },
                        set: { if let model = $0 { viewModel.selectModel(model) } }
                    )) { model in
                        ModelCard(
                            name: model.name,
                            type: model.modelFamily.rawValue,
                            purpose: model.purpose,
                            status: model.installed ? "Installed" : "Available",
                            statusColor: model.installed ? .green : .blue,
                            isSelected: viewModel.selectedModel?.id == model.id,
                            action: { viewModel.selectModel(model) }
                        )
                        .tag(model)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }

                if viewModel.isOffline {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Offline Mode (Mock Data)")
                            .font(.App.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
            }
            .frame(width: 320)
            .background(Color.App.background.opacity(0.5))

            Divider()

            // Detail View
            if let model = viewModel.selectedModel {
                ModelDetailView(model: model)
            } else {
                EmptyStateView(
                    title: "No Model Selected",
                    message: "Select a model from the list to view details.",
                    icon: "cpu"
                )
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedImportPath = url.path
                    viewModel.validateModelFolder(at: url.path)
                    showImportDialog = true
                }
            case .failure(let error):
                viewModel.errorMessage = "Failed to select folder: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showImportDialog) {
            importDialogView
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var importDialogView: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Import Model")
                .font(.App.title2)
                .padding(.bottom, Spacing.small)

            if let path = selectedImportPath {
                Text("Source: \(path)")
                    .font(.App.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Validating model...")
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if let result = viewModel.importValidationResult {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Image(systemName: result.canUse ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.canUse ? .green : .orange)
                        Text(result.message)
                            .font(.App.headline)
                    }

                    if !result.missingFiles.isEmpty {
                        Text("Missing files:")
                            .font(.App.caption)
                            .padding(.top, Spacing.xSmall)
                        ForEach(result.missingFiles, id: \.self) { file in
                            Text("• \(file)")
                                .font(.App.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !result.warnings.isEmpty {
                        Text("Warnings:")
                            .font(.App.caption)
                            .padding(.top, Spacing.xSmall)
                        ForEach(result.warnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.App.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Divider()
                        .padding(.vertical, Spacing.small)

                    Toggle("Copy files to models directory", isOn: $shouldCopy)
                        .font(.App.body)

                    Text(shouldCopy ? "Recommended. Files will be copied to the application's internal model storage." : "Advanced. A reference (symlink) will be created. Do not move the original folder.")
                        .font(.App.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.App.background.opacity(0.3))
                .cornerRadius(8)
            }

            Spacer()

            HStack {
                SecondaryButton("Cancel") {
                    showImportDialog = false
                }

                Spacer()

                PrimaryButton("Import", icon: "arrow.down.circle") {
                    if let path = selectedImportPath {
                        viewModel.importModel(
                            at: path,
                            copy: shouldCopy,
                            modelId: viewModel.importValidationResult?.matchedProfile?.id
                        )
                        showImportDialog = false
                    }
                }
                .disabled(!(viewModel.importValidationResult?.canUse ?? false) || viewModel.isImporting)
            }
        }
        .padding(Spacing.large)
        .frame(width: 500, height: 450)
    }
}

struct ModelDetailView: View {
    @EnvironmentObject private var appState: AppState
    let model: ModelProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        HStack {
                            Text(model.name)
                                .font(.App.title1)

                            if model.recommended {
                                StatusBadge(label: "Recommended", color: .green)
                            }
                        }

                        Text(model.modelFamily.rawValue)
                            .font(.App.headline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    StatusBadge(
                        label: model.installed ? "Installed" : "Available for Download",
                        color: model.installed ? .green : .blue
                    )
                }

                Text(model.purpose)
                    .font(.App.body)
                    .foregroundColor(.secondary)

                Divider()

                // Specs
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Recommended for your Mac: \(appState.hardwareProfile.generationProfile.description)")
                            .font(.App.caption)
                    }
                    .foregroundColor(Color.App.accent)
                    .padding(.bottom, Spacing.small)

                    Grid(alignment: .leading, horizontalSpacing: Spacing.large, verticalSpacing: Spacing.medium) {
                        GridRow {
                            DetailItem(label: "Memory Required", value: "\(model.memoryRequirement ?? 0) GB Unified Memory")
                            DetailItem(label: "Quality Level", value: model.qualityLevel.rawValue)
                        }
                        GridRow {
                            DetailItem(label: "Version", value: model.version ?? "1.0")
                            DetailItem(label: "Local Path", value: model.localPath ?? "Not installed")
                        }
                    }
                }

                Divider()

                // Actions
                HStack(spacing: Spacing.medium) {
                    if model.installed {
                        SecondaryButton("Validate", icon: "checkmark.shield") {
                            // Placeholder
                        }

                        SecondaryButton("Remove", icon: "trash", isDestructive: true) {
                            // Placeholder
                        }
                    } else {
                        PrimaryButton("Install Model", icon: "arrow.down.circle") {
                            // Placeholder
                        }
                    }
                }
                .padding(.top, Spacing.medium)

                Spacer()
            }
            .padding(Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
}

struct DetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
            Text(label)
                .font(.App.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.App.headline)
        }
    }
}
