import SwiftUI

struct ContinuityElementDetailView: View {
    @ObservedObject var viewModel: ContinuityLibraryViewModel
    @State private var editedElement: ContinuityElement
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingImagePicker = false
    @State private var isShowingAudioPicker = false

    init(viewModel: ContinuityLibraryViewModel, element: ContinuityElement) {
        self.viewModel = viewModel
        self._editedElement = State(initialValue: element)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerView

                Divider()

                if editedElement.type == .brand {
                    BrandKitEditorView(brandKit: Binding(
                        get: { BrandKit(element: editedElement) },
                        set: { newKit in
                            var updatedKit = newKit
                            updatedKit.syncElement()
                            editedElement = updatedKit.element
                        }
                    ))
                    Divider()
                }

                if editedElement.type == .audio {
                    // Audio Specific Editor (simplistic for now)
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Audio Identity Settings")
                            .font(.App.headline)

                        Text("Configure how this audio identity influences generation.")
                            .font(.App.caption)
                            .foregroundColor(.secondary)

                        // Placeholder for more complex audio settings
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Audio identities currently focus on prompt-based style guidance.")
                        }
                        .font(.App.caption)
                        .foregroundColor(Color.App.accent)
                        .padding(Spacing.small)
                        .background(Color.App.accent.opacity(0.1))
                        .cornerRadius(4)
                    }
                    Divider()
                }

                if editedElement.type == .voiceClone {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Voice Clone Settings")
                            .font(.App.headline)

                        Text("Upload a clear 5-30 second audio clip of the voice you want to clone.")
                            .font(.App.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            if let refPath = editedElement.voiceCloneReferencePath {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundColor(.green)
                                Text(URL(fileURLWithPath: refPath).lastPathComponent)
                                    .font(.App.caption)
                                    .lineLimit(1)

                                Spacer()

                                Button("Change") {
                                    isShowingAudioPicker = true
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Image(systemName: "mic.badge.plus")
                                    .foregroundColor(.secondary)
                                Text("No reference audio selected")
                                    .font(.App.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button("Select File") {
                                    isShowingAudioPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(Spacing.medium)
                        .background(Color.App.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.App.border, lineWidth: 1)
                        )
                    }
                    .fileImporter(
                        isPresented: $isShowingAudioPicker,
                        allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                editedElement.voiceCloneReferencePath = url.path
                            }
                        case .failure(let error):
                            print("Audio import failed: \(error.localizedDescription)")
                        }
                    }
                    Divider()
                }

                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Text("Details")
                        .font(.App.headline)

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Name")
                            .font(.App.caption)
                            .foregroundColor(.secondary)
                        TextField("Element Name", text: $editedElement.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Description")
                            .font(.App.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $editedElement.description)
                            .frame(height: 80)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.App.border, lineWidth: 1)
                            )
                    }
                }

                if editedElement.type != .brand && editedElement.type != .audio && editedElement.type != .voiceClone && editedElement.type != .camera && editedElement.type != .exportTemplate {
                    AssetGalleryView(
                        assets: editedElement.assets,
                        onAdd: { isShowingImagePicker = true },
                        onDelete: { assetId in
                            viewModel.removeAsset(from: editedElement.id, assetId: assetId)
                            if let updated = viewModel.elements.first(where: { $0.id == editedElement.id }) {
                                editedElement = updated
                            }
                        }
                    )
                    Divider()
                }

                if editedElement.type != .brand {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Prompt Generation")
                            .font(.App.headline)

                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("Prompt Block")
                                .font(.App.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $editedElement.promptBlock)
                                .frame(height: 100)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.App.border, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("Negative Prompt (Optional)")
                                .font(.App.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { editedElement.negativePrompt ?? "" },
                                set: { editedElement.negativePrompt = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.App.border, lineWidth: 1)
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Text("Metadata")
                        .font(.App.headline)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Created")
                                .font(.App.caption)
                                .foregroundColor(.secondary)
                            Text(editedElement.createdAt, style: .date)
                                .font(.App.body)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Modified")
                                .font(.App.caption)
                                .foregroundColor(.secondary)
                            Text(editedElement.modifiedAt, style: .date)
                                .font(.App.body)
                        }
                    }
                }

                Spacer(minLength: Spacing.xLarge)

                HStack {
                    SecondaryButton("Delete", icon: "trash") {
                        isShowingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)

                    Spacer()

                    PrimaryButton("Save Changes") {
                        saveChanges()
                    }
                }
            }
            .padding(Spacing.large)
        }
        .confirmationDialog(
            "Are you sure you want to delete this element?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteElement(editedElement.id)
            }
        }
        .fileImporter(
            isPresented: $isShowingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    viewModel.addAsset(to: editedElement.id, fileURL: url)
                }
                // Refresh local state
                if let updated = viewModel.elements.first(where: { $0.id == editedElement.id }) {
                    editedElement = updated
                }
            case .failure(let error):
                viewModel.error = error
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: editedElement.iconName)
                .font(.system(size: 32))
                .foregroundColor(Color.App.accent)
                .frame(width: 64, height: 64)
                .background(Color.App.accent.opacity(0.1))
                .cornerRadius(Spacing.medium)

            VStack(alignment: .leading, spacing: 4) {
                Text(editedElement.name)
                    .font(.App.title)
                Text(editedElement.type.rawValue.capitalized)
                    .font(.App.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func saveChanges() {
        editedElement.modifiedAt = Date()
        viewModel.updateElement(editedElement)
    }
}
