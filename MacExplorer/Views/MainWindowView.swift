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

                if let remotePane = appViewModel.remotePane {
                    RemotePaneView(
                        viewModel: remotePane,
                        isActive: appViewModel.activeSide == .right,
                        onActivate: { appViewModel.activeSide = .right },
                        onDisconnect: { appViewModel.disconnectRemotePane() }
                    )
                    .frame(minWidth: 360)
                } else {
                    PaneView(
                        viewModel: appViewModel.rightPane,
                        isActive: appViewModel.activeSide == .right,
                        onActivate: { appViewModel.activeSide = .right },
                        onRequestOtherPane: { appViewModel.leftPane.currentURL }
                    )
                    .frame(minWidth: 360)
                }
            }

            Divider()

            CommandBarView(appViewModel: appViewModel)
        }
        .sheet(isPresented: $appViewModel.isShowingSSHSheet) {
            SSHConnectionSheet(isPresented: $appViewModel.isShowingSSHSheet) { credentials in
                appViewModel.beginSSHConnection(credentials: credentials)
            }
        }
    }
}


/// Bottom command bar with Total Commander-style F-key actions. Observes the
/// currently active pane directly so button enabled-state (e.g. "Open in
/// IntelliJ") updates live as the selection changes.
private struct CommandBarView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var leftPane: PaneViewModel
    @ObservedObject var rightPane: PaneViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.leftPane = appViewModel.leftPane
        self.rightPane = appViewModel.rightPane
    }

    private var activePane: PaneViewModel {
        appViewModel.activeSide == .left ? leftPane : rightPane
    }

    var body: some View {
        HStack(spacing: 16) {
            Button("F5 Copy \u{2192}") { appViewModel.copyActiveSelectionToOtherPane() }
                .keyboardShortcut(.init("5"), modifiers: [])
            Button("F6 Move \u{2192}") { appViewModel.moveActiveSelectionToOtherPane() }
                .keyboardShortcut(.init("6"), modifiers: [])
            Button("F7 New Folder") { activePane.createFolder(named: "New Folder") }
                .keyboardShortcut(.init("7"), modifiers: [])
            Button("F8 Delete") { activePane.deleteSelection() }
                .keyboardShortcut(.init("8"), modifiers: [])
            Button {
                activePane.openSelectedFolderInIntelliJ()
            } label: {
                Label("Open in IntelliJ", systemImage: "hammer.fill")
            }
            .disabled(!activePane.canOpenInIntelliJ)
            Button {
                appViewModel.isShowingSSHSheet = true
            } label: {
                Label("Connect to SSH", systemImage: "network")
            }
            Spacer()
        }
        .buttonStyle(.bordered)
        .padding(8)
    }
}

#Preview {
    MainWindowView()
        .frame(width: 1000, height: 600)
}
