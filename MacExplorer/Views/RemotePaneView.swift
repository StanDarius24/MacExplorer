import SwiftUI

/// Browsable remote directory listing shown in the right pane once an SSH
/// connection succeeds. Supports navigation (open folder, Up, back/forward)
/// but is read-only in this pass — no remote file download/open/edit.
struct RemotePaneView: View {
    @ObservedObject var viewModel: RemotePaneViewModel
    let isActive: Bool
    let onActivate: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            statusBar
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button {
                Task { await viewModel.goBack() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)

            Button {
                Task { await viewModel.goForward() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)

            Button {
                Task { await viewModel.goUp() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(!viewModel.canGoUp)

            Text(viewModel.connectionLabel.isEmpty ? "Not Connected" : "\(viewModel.connectionLabel): \(viewModel.currentPath)")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            Button("Disconnect") {
                onDisconnect()
            }
        }
        .buttonStyle(.borderless)
        .padding(6)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.connectionState {
        case .connecting:
            VStack {
                Spacer()
                ProgressView("Connecting\u{2026}")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .disconnected:
            VStack {
                Spacer()
                Text("Not connected")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .connected:
            table
        }
    }

    private var table: some View {
        Table(viewModel.items, selection: $viewModel.selection) {
            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isDirectory ? "folder.fill" : (item.isSymbolicLink ? "link" : "doc"))
                        .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        .frame(width: 16)
                    Text(item.name)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await viewModel.open(item) }
                }
            }
            .width(min: 180, ideal: 260)

            TableColumn("Size") { item in
                Text(item.isDirectory ? "" : ByteCountFormatter.fileSize.string(fromByteCount: item.size))
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Modified") { item in
                Text(item.modificationDate.map(DateFormatter.shortDateTime.string(from:)) ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 150)
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
}

