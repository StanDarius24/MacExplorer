import Foundation

/// Thin wrapper around FileManager for directory listing and file operations.
/// Centralizing this makes it easy to swap in FSEvents-based live updates later.
struct FileSystemService {
    static let shared = FileSystemService()

    private let fileManager = FileManager.default

    /// Lists the immediate contents of a directory. Hidden files are skipped
    /// unless `showHidden` is true (mirrors a common Total Commander toggle).
    func contents(of directoryURL: URL, showHidden: Bool = false) throws -> [FileItem] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHidden {
            options.insert(.skipsHiddenFiles)
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .localizedTypeDescriptionKey
            ],
            options: options
        )

        return urls.map(FileItem.init)
    }

    func createFolder(named name: String, in directoryURL: URL) throws -> URL {
        let newURL = directoryURL.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    func rename(_ url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: url, to: destination)
        return destination
    }

    func moveToTrash(_ urls: [URL]) throws {
        for url in urls {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    func copy(_ urls: [URL], to destinationDirectory: URL) throws {
        for url in urls {
            let destination = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
        }
    }

    func move(_ urls: [URL], to destinationDirectory: URL) throws {
        for url in urls {
            let destination = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: url, to: destination)
        }
    }

    func directorySize(of url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += Int64(size ?? 0)
        }
        return total
    }
}
