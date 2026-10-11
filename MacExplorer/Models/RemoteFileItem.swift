import Foundation
import Citadel

/// Represents a single file or folder entry in a remote SFTP directory listing.
/// Mirrors `FileItem`'s shape so remote browsing can reuse similar UI patterns,
/// but paths are POSIX remote paths (always "/"-separated) rather than local URLs.
///
/// Marked `nonisolated` throughout because instances are built inside the
/// `SSHConnectionService` actor (off the main actor) and then handed back to
/// `RemotePaneViewModel` on the main actor; the project's default actor
/// isolation setting would otherwise make these members main-actor-isolated.
nonisolated struct RemoteFileItem: Identifiable, Hashable {
    let id: String
    /// Absolute remote path, e.g. "/home/user/Documents".
    let path: String
    let name: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let size: Int64
    let modificationDate: Date?

    static func == (lhs: RemoteFileItem, rhs: RemoteFileItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Builds a `RemoteFileItem` from an SFTP directory entry, resolving its
    /// absolute path relative to the directory it was listed from.
    init(component: SFTPPathComponent, parentPath: String) {
        self.name = component.filename
        self.path = RemoteFileItem.joinPath(parentPath, component.filename)
        self.id = path

        // SFTP has no portable "is directory" flag on SFTPFileAttributes; the
        // longname (an "ls -l" style string) is the most reliable indicator
        // available from Citadel's v3 protocol implementation.
        let longname = component.longname
        let firstChar = longname.first
        self.isDirectory = firstChar == "d"
        self.isSymbolicLink = firstChar == "l"
        self.size = Int64(component.attributes.size ?? 0)
        self.modificationDate = component.attributes.accessModificationTime?.modificationTime
    }

    private static func joinPath(_ parent: String, _ name: String) -> String {
        if parent.hasSuffix("/") {
            return parent + name
        }
        return parent + "/" + name
    }

    /// Synthetic entry used for the ".." (parent directory) row.
    static func parentEntry(for path: String) -> RemoteFileItem {
        RemoteFileItem(
            id: path + "/..",
            path: path,
            name: "..",
            isDirectory: true,
            isSymbolicLink: false,
            size: 0,
            modificationDate: nil
        )
    }

    private init(id: String, path: String, name: String, isDirectory: Bool, isSymbolicLink: Bool, size: Int64, modificationDate: Date?) {
        self.id = id
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.size = size
        self.modificationDate = modificationDate
    }
}
