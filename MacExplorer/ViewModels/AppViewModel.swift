import Foundation
import SwiftUI
import Combine

/// Owns the two panes of the dual-pane window and tracks which one is active,
/// mirroring Total Commander's left/right pane model.
@MainActor
final class AppViewModel: ObservableObject {
    enum PaneSide {
        case left
        case right
    }

    @Published var leftPane: PaneViewModel
    @Published var rightPane: PaneViewModel
    @Published var activeSide: PaneSide = .left

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

    func copyActiveSelectionToOtherPane() {
        activePane.copySelection(to: inactivePane.currentURL)
        inactivePane.reload()
    }

    func moveActiveSelectionToOtherPane() {
        activePane.moveSelection(to: inactivePane.currentURL)
        inactivePane.reload()
    }
}
