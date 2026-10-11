import Foundation
import SwiftUI
import Combine
import Citadel

/// Drives the remote (SSH/SFTP) pane: connection lifecycle, current remote
/// directory, listing, and navigation. Mirrors `PaneViewModel`'s shape so the
/// dual-pane UI stays consistent, but talks to a remote server instead of
/// the local filesystem.
@MainActor
final class RemotePaneViewModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentPath: String = "/"
    @Published var items: [RemoteFileItem] = []
    @Published var selection: Set<String> = []
    @Published var errorMessage: String?
    @Published var connectionLabel: String = ""

    private let service = SSHConnectionService()
    private var backStack: [String] = []
    private var forwardStack: [String] = []

    var isConnected: Bool {
        connectionState == .connected
    }

    var canGoUp: Bool {
        currentPath != "/" && !currentPath.isEmpty
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    var selectedItems: [RemoteFileItem] {
        items.filter { selection.contains($0.id) }
    }

    var selectionSummary: String {
        if items.isEmpty {
            return "0 items"
        }
        let selected = selectedItems
        guard !selected.isEmpty else {
            return "\(items.count) items"
        }
        return "\(selected.count) of \(items.count) selected"
    }

    /// Connects using the given credentials, then loads the server's home
    /// directory listing on success.
    func connect(credentials: SSHConnectionService.Credentials) async {
        connectionState = .connecting
        errorMessage = nil

        do {
            try await service.connect(with: credentials)
            let home = try await service.resolveHomeDirectory()
            connectionLabel = "\(credentials.username)@\(credentials.host)"
            connectionState = .connected
            backStack.removeAll()
            forwardStack.removeAll()
            await navigate(to: home, pushHistory: false)
        } catch {
            connectionState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await service.disconnect()
        connectionState = .disconnected
        items = []
        selection.removeAll()
        backStack.removeAll()
        forwardStack.removeAll()
        currentPath = "/"
        connectionLabel = ""
    }

    func reload() async {
        await load(path: currentPath)
    }

    func navigate(to path: String, pushHistory: Bool = true) async {
        guard path != currentPath || items.isEmpty else { return }
        if pushHistory {
            backStack.append(currentPath)
            forwardStack.removeAll()
        }
        selection.removeAll()
        await load(path: path)
    }

    func open(_ item: RemoteFileItem) async {
        guard item.isDirectory else { return }
        await navigate(to: item.path)
    }

    func goUp() async {
        guard canGoUp else { return }
        let parent = (currentPath as NSString).deletingLastPathComponent
        await navigate(to: parent.isEmpty ? "/" : parent)
    }

    func goBack() async {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentPath)
        selection.removeAll()
        await load(path: previous)
    }

    func goForward() async {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentPath)
        selection.removeAll()
        await load(path: next)
    }

    private func load(path: String) async {
        do {
            let fetched = try await service.listDirectory(atPath: path)
            items = fetched
            currentPath = path
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
