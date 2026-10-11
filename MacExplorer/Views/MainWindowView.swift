import SwiftUI

/// Top-level dual-pane layout: left pane | divider | right pane, with a
/// shared command bar for cross-pane operations (copy/move), similar to
/// Total Commander's F5/F6 bar.
struct MainWindowView: View {
    @StateObject private var appViewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                PaneView(
                    viewModel: appViewModel.leftPane,
                    isActive: appViewModel.activeSide == .left,
                    onActivate: { appViewModel.activeSide = .left },
                    onRequestOtherPane: { appViewModel.rightPane.currentURL }
                )
                .frame(minWidth: 360)

                PaneView(
                    viewModel: appViewModel.rightPane,
                    isActive: appViewModel.activeSide == .right,
                    onActivate: { appViewModel.activeSide = .right },
                    onRequestOtherPane: { appViewModel.leftPane.currentURL }
                )
                .frame(minWidth: 360)
            }

            Divider()

            HStack(spacing: 16) {
                Button("F5 Copy \u{2192}") { appViewModel.copyActiveSelectionToOtherPane() }
                    .keyboardShortcut(.init("5"), modifiers: [])
                Button("F6 Move \u{2192}") { appViewModel.moveActiveSelectionToOtherPane() }
                    .keyboardShortcut(.init("6"), modifiers: [])
                Button("F7 New Folder") { appViewModel.activePane.createFolder(named: "New Folder") }
                    .keyboardShortcut(.init("7"), modifiers: [])
                Button("F8 Delete") { appViewModel.activePane.deleteSelection() }
                    .keyboardShortcut(.init("8"), modifiers: [])
                Spacer()
            }
            .buttonStyle(.bordered)
            .padding(8)
        }
    }
}

#Preview {
    MainWindowView()
        .frame(width: 1000, height: 600)
}
