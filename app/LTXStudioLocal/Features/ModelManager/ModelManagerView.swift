import SwiftUI

struct ModelManagerView: View {
    @StateObject private var viewModel = ModelManagerViewModel(modelStore: RemoteModelStore())

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List
            VStack(alignment: .leading, spacing: 0) {
                Text("Models")
                    .font(.App.title3)
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
                    subtitle: "Select a model from the list to view details.",
                    icon: "cpu"
                )
            }
        }
    }
}

struct ModelDetailView: View {
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

                Divider()

                // Actions
                HStack(spacing: Spacing.medium) {
                    if model.installed {
                        SecondaryButton(title: "Validate", icon: "checkmark.shield") {
                            // Placeholder
                        }

                        SecondaryButton(title: "Remove", icon: "trash", isDestructive: true) {
                            // Placeholder
                        }
                    } else {
                        PrimaryButton(title: "Install Model", icon: "arrow.down.circle") {
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
