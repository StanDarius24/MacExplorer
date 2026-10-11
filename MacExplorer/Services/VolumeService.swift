import Foundation

/// Enumerates mounted volumes for an optional "Volumes" shortcut section.
struct VolumeService {
    static let shared = VolumeService()

    func mountedVolumes() -> [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }
}
