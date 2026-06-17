import Foundation
import Combine
import SwiftUI

@MainActor
class ContinuityLibraryViewModel: ObservableObject {
    private let store: ContinuityStore

    @Published var elements: [ContinuityElement] = []
    @Published var selectedCategory: ContinuityElementType?
    @Published var searchText: String = ""
    @Published var selectedElementId: String?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var importSummary: ImportSummary?
    @Published var showingImportConflictDialog: Bool = false
    @Published var pendingImportElements: [ContinuityElement] = []

    init(store: ContinuityStore = FileContinuityStore()) {
        self.store = store
        loadElements()
    }

    func loadElements() {
        isLoading = true
        do {
            elements = try store.loadAll()
            if elements.isEmpty {
                try store.loadDefaultElements()
                elements = try store.loadAll()
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    var filteredElements: [ContinuityElement] {
        elements.filter { element in
            let matchesCategory = selectedCategory == nil || element.type == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                element.name.localizedCaseInsensitiveContains(searchText) ||
                element.description.localizedCaseInsensitiveContains(searchText) ||
                element.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesSearch
        }
    }

    var selectedElement: ContinuityElement? {
        elements.first { $0.id == selectedElementId }
    }

    func selectElement(_ elementId: String?) {
        selectedElementId = elementId
    }

    func createNewElement(type: ContinuityElementType) {
        let newElement = ContinuityElement(
            type: type,
            name: "New \(type.rawValue.capitalized)",
            promptBlock: ""
        )
        do {
            try store.save(newElement)
            elements.append(newElement)
            selectedElementId = newElement.id
        } catch {
            self.error = error
        }
    }

    func updateElement(_ element: ContinuityElement) {
        do {
            try store.save(element)
            if let index = elements.firstIndex(where: { $0.id == element.id }) {
                elements[index] = element
            }
        } catch {
            self.error = error
        }
    }

    func deleteElement(_ elementId: String) {
        guard let element = elements.first(where: { $0.id == elementId }) else { return }
        do {
            try store.delete(elementId: elementId, type: element.type)
            elements.removeAll { $0.id == elementId }
            if selectedElementId == elementId {
                selectedElementId = nil
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Import / Export

    func exportLibrary(to url: URL, selectedIds: Set<String>) {
        isLoading = true
        do {
            let elementsToExport = elements.filter { selectedIds.isEmpty || selectedIds.contains($0.id) }
            try store.export(elements: elementsToExport, to: url)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func prepareImport(from urls: [URL]) {
        isLoading = true
        var toImport: [ContinuityElement] = []
        var summary = ImportSummary()

        for url in urls {
            // If it's a directory, we should probably traverse it, but fileImporter with .directory handles it
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    for file in files where file.pathExtension == "json" {
                        processFile(file, &toImport, &summary)
                    }
                } catch {
                    summary.failed += 1
                    summary.errors.append("Failed to read directory \(url.lastPathComponent): \(error.localizedDescription)")
                }
            } else if url.pathExtension == "json" {
                processFile(url, &toImport, &summary)
            }
        }

        if toImport.isEmpty && summary.failed > 0 {
            self.importSummary = summary
            isLoading = false
        } else if !toImport.isEmpty {
            self.pendingImportElements = toImport
            self.showingImportConflictDialog = true
            // summary will be updated during actual import
            self.importSummary = summary
            isLoading = false
        } else {
            // Nothing found
            summary.errors.append("No valid continuity element JSON files found.")
            self.importSummary = summary
            isLoading = false
        }
    }

    private func processFile(_ url: URL, _ toImport: inout [ContinuityElement], _ summary: inout ImportSummary) {
        do {
            let data = try Data(contentsOf: url)
            let element = try store.validateElement(from: data)
            toImport.append(element)
        } catch {
            summary.failed += 1
            summary.errors.append("Failed to validate \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func confirmImport(strategy: ImportConflictStrategy) {
        var summary = self.importSummary ?? ImportSummary()
        isLoading = true

        for var element in pendingImportElements {
            let exists = elements.contains { $0.id == element.id }

            if exists {
                switch strategy {
                case .skip:
                    summary.skipped += 1
                case .replace:
                    do {
                        try store.save(element)
                        if let index = elements.firstIndex(where: { $0.id == element.id }) {
                            elements[index] = element
                        }
                        summary.updated += 1
                    } catch {
                        summary.failed += 1
                        summary.errors.append("Failed to update \(element.name): \(error.localizedDescription)")
                    }
                case .keepBoth:
                    do {
                        // Create a copy with a new ID
                        let newId = UUID().uuidString
                        let newName = "\(element.name) (Copy)"
                        element = ContinuityElement(
                            id: newId,
                            type: element.type,
                            name: newName,
                            description: element.description,
                            promptBlock: element.promptBlock,
                            negativePrompt: element.negativePrompt,
                            tags: element.tags,
                            assets: element.assets,
                            createdAt: element.createdAt,
                            modifiedAt: Date()
                        )
                        try store.save(element)
                        elements.append(element)
                        summary.imported += 1
                    } catch {
                        summary.failed += 1
                        summary.errors.append("Failed to import copy of \(element.name): \(error.localizedDescription)")
                    }
                }
            } else {
                do {
                    try store.save(element)
                    elements.append(element)
                    summary.imported += 1
                } catch {
                    summary.failed += 1
                    summary.errors.append("Failed to import \(element.name): \(error.localizedDescription)")
                }
            }
        }

        self.importSummary = summary
        self.pendingImportElements = []
        self.showingImportConflictDialog = false
        isLoading = false
    }
    func importFromFolder(url: URL) {
        isLoading = true
        do {
            try store.importLibrary(from: url)
            loadElements() // Refresh
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
