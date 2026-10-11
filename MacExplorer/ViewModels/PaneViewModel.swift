import Foundation
import SwiftUI
import AppKit
import Combine

/// Drives a single pane: current directory, navigation history, listing,
/// sorting, and selection. Two instances live side-by-side in the dual-pane UI.
@MainActor
final class PaneViewModel: ObservableObject {
    @Published var currentURL: URL
    @Published var items: [FileItem] = []
    @Published var selection: Set<URL> = []
    @Published var sortField: SortField = .name
    @Published var sortOrder: SortOrder = .ascending
    @Published var showHidden: Bool = false
    @Published var errorMessage: String?

    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    init(startURL: URL) {
        self.currentURL = startURL
        reload()
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { currentURL.pathComponents.count > 1 }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.url) }
    }

    var totalSizeDescription: String {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.fileSize.string(fromByteCount: total)
    }

    var selectionSummary: String {
        let selected = selectedItems
        guard !selected.isEmpty else {
            return "\(items.count) items, \(totalSizeDescription)"
        }
        let size = selected.reduce(Int64(0)) { $0 + $1.size }
        return "\(selected.count) of \(items.count) selected, \(ByteCountFormatter.fileSize.string(fromByteCount: size))"
    }

    func reload() {
        do {
            let fetched = try FileSystemService.shared.contents(of: currentURL, showHidden: showHidden)
            items = sorted(fetched)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    func sorted(_ items: [FileItem]) -> [FileItem] {
        let dirsFirst = items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let ascending: Bool
            switch sortField {
            case .name:
                ascending = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                ascending = lhs.size < rhs.size
            case .date:
                ascending = (lhs.modificationDate ?? .distantPast) < (rhs.modificationDate ?? .distantPast)
            case .kind:
                ascending = lhs.kindDescription.localizedStandardCompare(rhs.kindDescription) == .orderedAscending
            }
            return sortOrder == .ascending ? ascending : !ascending
        }
        return dirsFirst
    }

    func setSortField(_ field: SortField) {
        if sortField == field {
            sortOrder.toggle()
        } else {
            sortField = field
            sortOrder = .ascending
        }
        items = sorted(items)
    }

    func navigate(to url: URL, pushHistory: Bool = true) {
        guard url != currentURL else { return }
        if pushHistory {
            backStack.append(currentURL)
            forwardStack.removeAll()
        }
        currentURL = url
        selection.removeAll()
        reload()
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func goUp() {
        guard canGoUp else { return }
        navigate(to: currentURL.deletingLastPathComponent())
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentURL)
        currentURL = previous
        selection.removeAll()
        reload()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentURL)
        currentURL = next
        selection.removeAll()
        reload()
    }

    func createFolder(named name: String) {
        do {
            _ = try FileSystemService.shared.createFolder(named: name, in: currentURL)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ item: FileItem, to newName: String) {
        do {
            _ = try FileSystemService.shared.rename(item.url, to: newName)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelection() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        do {
            try FileSystemService.shared.moveToTrash(urls)
            selection.removeAll()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copySelection(to destination: URL) {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        do {
            try FileSystemService.shared.copy(urls, to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSelection(to destination: URL) {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        do {
            try FileSystemService.shared.move(urls, to: destination)
            selection.removeAll()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
