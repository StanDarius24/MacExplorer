import SwiftUI

/// A single file-list pane: path bar, sortable table, and status footer.
/// Two of these are shown side by side in `MainWindowView`.
struct PaneView: View {
    @ObservedObject var viewModel: PaneViewModel
    let isActive: Bool
    let onActivate: () -> Void
    let onRequestOtherPane: () -> URL?

    @State private var pathFieldText: String = ""
    @State private var renamingItem: FileItem?
    @State private var renameText: String = ""
    @State private var isCreatingFolder = false
    @State private var newFolderName: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            table
            Divider()
            statusBar
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .onAppear { pathFieldText = viewModel.currentURL.path }
        .onChange(of: viewModel.currentURL) { _, newValue in
            pathFieldText = newValue.path
        }
        .alert("Delete selected items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { viewModel.deleteSelection() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The selected items will be moved to the Trash.")
        }
        .sheet(item: $renamingItem) { item in
            renameSheet(for: item)
        }
        .sheet(isPresented: $isCreatingFolder) {
            newFolderSheet
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: viewModel.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)

            Button(action: viewModel.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)

            Button(action: viewModel.goUp) {
                Image(systemName: "arrow.up")
            }
            .disabled(!viewModel.canGoUp)

            TextField("Path", text: $pathFieldText, onCommit: navigateToTypedPath)
                .textFieldStyle(.roundedBorder)

            Button(action: viewModel.reload) {
                Image(systemName: "arrow.clockwise")
            }

            Button {
                newFolderName = "New Folder"
                isCreatingFolder = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }

            Toggle(isOn: $viewModel.showHidden) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .onChange(of: viewModel.showHidden) { _, _ in viewModel.reload() }
        }
        .buttonStyle(.borderless)
        .padding(6)
    }

    private var table: some View {
        Table(viewModel.items, selection: $viewModel.selection) {
            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(item.name)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { viewModel.open(item) }
            }
            .width(min: 160, ideal: 260)

            TableColumn("Size") { item in
                Text(item.isDirectory ? "" : ByteCountFormatter.fileSize.string(fromByteCount: item.size))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Date Modified") { item in
                Text(item.modificationDate.map { DateFormatter.shortDateTime.string(from: $0) } ?? "")
            }
            .width(min: 120, ideal: 160)

            TableColumn("Kind") { item in
                Text(item.kindDescription)
            }
            .width(min: 90, ideal: 120)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            contextMenuItems(for: urls)
        }
        .onDeleteCommand { showDeleteConfirmation = true }
    }

    @ViewBuilder
    private func contextMenuItems(for urls: Set<URL>) -> some View {
        if urls.count == 1, let url = urls.first, let item = viewModel.items.first(where: { $0.url == url }) {
            Button("Open") { viewModel.open(item) }
            Button("Rename\u{2026}") {
                renameText = item.name
                renamingItem = item
            }
        }
        Button("Delete", role: .destructive) {
            viewModel.selection = urls
            showDeleteConfirmation = true
        }
        if let destination = onRequestOtherPane() {
            Divider()
            Button("Copy to Other Pane") {
                viewModel.selection = urls
                viewModel.copySelection(to: destination)
            }
            Button("Move to Other Pane") {
                viewModel.selection = urls
                viewModel.moveSelection(to: destination)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text(viewModel.selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func renameSheet(for item: FileItem) -> some View {
        VStack(spacing: 12) {
            Text("Rename \u{201C}\(item.name)\u{201D}")
                .font(.headline)
            TextField("New name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Spacer()
                Button("Cancel") { renamingItem = nil }
                Button("Rename") {
                    viewModel.rename(item, to: renameText)
                    renamingItem = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private var newFolderSheet: some View {
        VStack(spacing: 12) {
            Text("New Folder")
                .font(.headline)
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Spacer()
                Button("Cancel") { isCreatingFolder = false }
                Button("Create") {
                    viewModel.createFolder(named: newFolderName)
                    isCreatingFolder = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func navigateToTypedPath() {
        let expanded = (pathFieldText as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            pathFieldText = viewModel.currentURL.path
            return
        }
        viewModel.navigate(to: URL(fileURLWithPath: expanded))
    }
}
