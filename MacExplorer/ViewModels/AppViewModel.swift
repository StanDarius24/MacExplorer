import Foundation
import SwiftUI
import Combine

/// Owns the two panes of the dual-pane window and tracks which one is active,
/// mirroring Total Commander's left/right pane model. The right pane can
/// optionally show a remote SSH/SFTP directory listing instead of the local
/// filesystem.
@MainActor
final class AppViewModel: ObservableObject {
    enum PaneSide {
        case left
        case right
    }

    @Published var leftPane: PaneViewModel
    @Published var rightPane: PaneViewModel
    @Published var activeSide: PaneSide = .left

    /// Non-nil while the right pane is showing a remote (SSH) listing instead
    /// of the local `rightPane`.
    @Published var remotePane: RemotePaneViewModel?
    @Published var isShowingSSHSheet = false

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        leftPane = PaneViewModel(startURL: home)
        rightPane = PaneViewModel(startURL: home)
    }

    var activePane: PaneViewModel {
        activeSide == .left ? leftPane : rightPane
    }

    var inactivePane: PaneViewModel {
        activeSide == .left ? rightPane : leftPane
    }

    var isShowingRemotePane: Bool {
        remotePane != nil
    }

    func copyActiveSelectionToOtherPane() {
        activePane.copySelection(to: inactivePane.currentURL)
        inactivePane.reload()
    }

    func moveActiveSelectionToOtherPane() {
        activePane.moveSelection(to: inactivePane.currentURL)
        inactivePane.reload()
    }

    func beginSSHConnection(credentials: SSHConnectionService.Credentials) {
        let remoteViewModel = RemotePaneViewModel()
        remotePane = remoteViewModel
        activeSide = .right
        Task {
            await remoteViewModel.connect(credentials: credentials)
        }
    }

    func disconnectRemotePane() {
        guard let remotePane else { return }
        Task {
            await remotePane.disconnect()
        }
        self.remotePane = nil
    }
}

