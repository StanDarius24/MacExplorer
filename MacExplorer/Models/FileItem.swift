import Foundation
import AppKit

/// Represents a single file or folder entry shown in a pane.
struct FileItem: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let kindDescription: String

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    init(url: URL) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent

        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .localizedTypeDescriptionKey
        ])

        self.isDirectory = resourceValues?.isDirectory ?? false
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.modificationDate = resourceValues?.contentModificationDate
        self.kindDescription = resourceValues?.localizedTypeDescription
            ?? (self.isDirectory ? "Folder" : "File")
    }

    /// Synthetic entry used for the ".." (parent directory) row.
    static func parentEntry(for url: URL) -> FileItem {
        FileItem(url: url)
    }
}
