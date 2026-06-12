import SwiftUI

struct ProjectTemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [ProjectTemplate] = ProjectTemplate.defaultTemplates

    @State private var selectedTemplateId: String?
    @State private var projectName: String = "My New Project"
    @State private var useDefaultBrandKit: Bool = true

    var onSelect: (ProjectTemplate, String, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Project")
                    .font(.App.title)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.App.headline)
                        .foregroundColor(Color.App.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xxLarge)
            .padding(.vertical, Spacing.large)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Template List
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Choose a Template")
                            .font(.App.headline)
                            .padding(.bottom, Spacing.small)

                        ForEach(templates) { template in
                            TemplateRow(
                                template: template,
                                isSelected: selectedTemplateId == template.id
                            ) {
                                selectedTemplateId = template.id
                            }
                        }

                        // Blank Project Option
                        TemplateRow(
                            template: ProjectTemplate(
                                id: "blank",
                                name: "Blank Project",
                                description: "Start from scratch with a single empty scene.",
                                icon: "doc.fill",
                                aspectRatio: "16:9",
                                sceneStructures: [SceneTemplateStructure(name: "Scene 1")]
                            ),
                            isSelected: selectedTemplateId == "blank" || selectedTemplateId == nil
                        ) {
                            selectedTemplateId = "blank"
                        }
                    }
                    .padding(Spacing.xxLarge)
                }
                .frame(width: 350)

                Divider()

                // Configuration Area
                VStack(alignment: .leading, spacing: Spacing.xxxLarge) {
                    if let template = currentTemplate {
                        VStack(alignment: .leading, spacing: Spacing.medium) {
                            Text("Project Details")
                                .font(.App.headline)

                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Project Name")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)
                                TextField("Enter project name", text: $projectName)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                            }

                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Structure")
                                    .font(.App.caption)
                                    .foregroundColor(Color.App.secondaryText)

                                ScrollView {
                                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                        ForEach(template.sceneStructures, id: \.name) { scene in
                                            HStack {
                                                Image(systemName: "film")
                                                    .foregroundColor(Color.App.accent)
                                                Text(scene.name)
                                                    .font(.App.body)
                                                Spacer()
                                            }
                                            .padding(Spacing.small)
                                            .background(Color.App.secondaryBackground)
                                            .cornerRadius(Spacing.cornerRadiusMedium)
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }

                            Toggle("Attach Default Brand Kit", isOn: $useDefaultBrandKit)
                                .font(.App.body)
                                .padding(.top, Spacing.small)

                            HStack {
                                Label("\(template.aspectRatio)", systemImage: "aspectratio")
                                    .font(.App.caption)
                                    .padding(.horizontal, Spacing.small)
                                    .padding(.vertical, 4)
                                    .background(Color.App.accent.opacity(0.1))
                                    .foregroundColor(Color.App.accent)
                                    .cornerRadius(4)

                                Spacer()
                            }
                        }

                        Spacer()

                        HStack {
                            Spacer()
                            SecondaryButton("Cancel") {
                                dismiss()
                            }
                            PrimaryButton("Create Project") {
                                onSelect(template, projectName, useDefaultBrandKit)
                                dismiss()
                            }
                        }
                    } else {
                        EmptyStateView(
                            title: "No Template Selected",
                            message: "Select a template from the list on the left to see details.",
                            icon: "doc.text.magnifyingglass"
                        )
                    }
                }
                .padding(Spacing.xxLarge)
                .frame(maxWidth: .infinity)
                .background(Color.App.surface)
            }
        }
        .frame(width: 800, height: 600)
    }

    private var currentTemplate: ProjectTemplate? {
        if selectedTemplateId == "blank" {
            return ProjectTemplate(
                id: "blank",
                name: "Blank Project",
                description: "Start from scratch with a single empty scene.",
                icon: "doc.fill",
                aspectRatio: "16:9",
                sceneStructures: [SceneTemplateStructure(name: "Scene 1")]
            )
        }
        return templates.first { $0.id == selectedTemplateId } ?? templates.first
    }
}

struct TemplateRow: View {
    let template: ProjectTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusMedium)
                        .fill(isSelected ? Color.App.accent : Color.App.secondaryBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : Color.App.secondaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.App.headline)
                        .foregroundColor(isSelected ? Color.App.accent : Color.App.text)

                    Text(template.description)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.App.accent)
                }
            }
            .padding(Spacing.medium)
            .background(isSelected ? Color.App.accent.opacity(0.05) : Color.clear)
            .cornerRadius(Spacing.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .stroke(isSelected ? Color.App.accent : Color.App.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
