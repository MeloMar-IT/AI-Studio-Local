import SwiftUI
import UniformTypeIdentifiers

struct FolderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }

    init() {}
    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(directoryWithFileWrappers: [:])
    }
}

struct ContinuityLibraryView: View {
    @StateObject private var viewModel = ContinuityLibraryViewModel()
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var exportUrl: URL?

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            ContinuityElementListView(viewModel: viewModel)
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItemGroup {
                        importExportMenu

                        Menu {
                            ForEach(ContinuityElementType.allCases, id: \.self) { type in
                                Button(type.rawValue.capitalized) {
                                    viewModel.createNewElement(type: type)
                                }
                            }
                        } label: {
                            Label("Add Element", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let selectedElement = viewModel.selectedElement {
                ContinuityElementDetailView(viewModel: viewModel, element: selectedElement)
                    .id(selectedElement.id)
            } else {
                EmptyStateView(
                    title: "Select an element",
                    message: "Choose an element from the list or create a new one to get started.",
                    icon: "person.2.square.stack"
                )
            }
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.folder, .json],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.prepareImport(from: urls)
            case .failure(let error):
                viewModel.error = error
            }
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: FolderDocument(),
            contentType: .folder,
            defaultFilename: "ContinuityLibraryExport"
        ) { result in
            switch result {
            case .success(let url):
                viewModel.exportLibrary(to: url, selectedIds: [])
            case .failure(let error):
                viewModel.error = error
            }
        }
        .sheet(item: $viewModel.importSummary) { summary in
            importSummarySheet(summary)
        }
        .confirmationDialog(
            "Conflict Handling",
            isPresented: $viewModel.showingImportConflictDialog,
            titleVisibility: .visible
        ) {
            Button("Replace Existing") {
                viewModel.confirmImport(strategy: .replace)
            }
            Button("Keep Both (Create Copies)") {
                viewModel.confirmImport(strategy: .keepBoth)
            }
            Button("Skip Duplicates", role: .cancel) {
                viewModel.confirmImport(strategy: .skip)
            }
        } message: {
            Text("Some elements you are importing already exist in your library. How would you like to handle them?")
        }
    }

    private var importExportMenu: some View {
        Menu {
            Button {
                showingImportDialog = true
            } label: {
                Label("Import Library folder...", systemImage: "square.and.arrow.down")
            }

            Divider()

            Button {
                showingExportDialog = true
            } label: {
                Label("Export Entire Library...", systemImage: "square.and.arrow.up")
            }

            Button {
                if viewModel.selectedElementId != nil {
                    // In a real app we might want a picker for which folder,
                    // but for now we'll just use the exporter
                    showingExportDialog = true
                    // Note: fileExporter doesn't easily let us pass state,
                    // we'd need a more complex setup to handle "selected only" vs "all"
                    // in the same exporter call without extra UI.
                }
            } label: {
                Label("Export Selected Element...", systemImage: "doc.badge.arrow.up")
            }
            .disabled(viewModel.selectedElementId == nil)

        } label: {
            Label("Import/Export", systemImage: "arrow.up.and.down.square")
        }
    }

    private func importSummarySheet(_ summary: ImportSummary) -> some View {
        VStack(spacing: Spacing.large) {
            Text("Import Results")
                .font(.App.title)

            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack {
                    Text("Total Processed:")
                    Spacer()
                    Text("\(summary.totalProcessed)")
                        .bold()
                }

                Divider()

                Group {
                    summaryRow(label: "Imported New:", value: summary.imported, color: .green)
                    summaryRow(label: "Updated Existing:", value: summary.updated, color: .blue)
                    summaryRow(label: "Skipped:", value: summary.skipped, color: .secondary)
                    summaryRow(label: "Failed:", value: summary.failed, color: .red)
                }
            }
            .padding()
            .background(Color.App.secondaryBackground)
            .cornerRadius(Spacing.medium)

            if !summary.errors.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Issues:")
                        .font(.App.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(summary.errors, id: \.self) { error in
                                Text("• \(error)")
                                    .font(.App.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            PrimaryButton("Done") {
                viewModel.importSummary = nil
            }
        }
        .padding(Spacing.xxxLarge)
        .frame(width: 400)
    }

    private func summaryRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .foregroundColor(value > 0 ? color : .secondary)
                .bold(value > 0)
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedCategory) {
            Text("Categories")
                .font(.App.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, Spacing.small)

            NavigationLink(value: nil as ContinuityElementType?) {
                Label("All Elements", systemImage: "square.grid.2x2")
            }

            Section {
                ForEach(ContinuityElementType.allCases, id: \.self) { type in
                    NavigationLink(value: type) {
                        Label(type.rawValue.capitalized, systemImage: iconForType(type))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Continuity")
    }

    private func iconForType(_ type: ContinuityElementType) -> String {
        switch type {
        case .character: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .style: return "paintpalette.fill"
        case .camera: return "video.fill"
        case .audio: return "waveform"
        case .brand: return "briefcase.fill"
        case .promptBlock: return "text.alignleft"
        case .lora: return "cpu"
        case .exportTemplate: return "square.and.arrow.up.fill"
        }
    }
}
