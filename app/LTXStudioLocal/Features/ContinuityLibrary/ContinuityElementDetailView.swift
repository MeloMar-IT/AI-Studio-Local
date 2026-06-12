import SwiftUI

struct ContinuityElementDetailView: View {
    @ObservedObject var viewModel: ContinuityLibraryViewModel
    @State private var editedElement: ContinuityElement
    @State private var isShowingDeleteConfirmation = false

    init(viewModel: ContinuityLibraryViewModel, element: ContinuityElement) {
        self.viewModel = viewModel
        self._editedElement = State(initialValue: element)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerView

                Divider()

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
