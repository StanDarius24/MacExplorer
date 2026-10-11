import Foundation
import AppKit

/// Launches directories in external developer tools. Currently supports
/// IntelliJ IDEA; the app runs unsandboxed so no entitlements are required.
struct ExternalAppLauncher {
    static let shared = ExternalAppLauncher()

    /// Known bundle identifiers to try, in order of preference
    /// (Ultimate and Community editions use different IDs).
    private let intelliJBundleIdentifiers = [
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce"
    ]

    /// Fallback install locations in case Launch Services hasn't indexed the app.
    private let intelliJFallbackPaths = [
        "/Applications/IntelliJ IDEA.app",
        "/Applications/IntelliJ IDEA CE.app",
        "~/Applications/IntelliJ IDEA.app",
        "~/Applications/IntelliJ IDEA CE.app"
    ]

    func locateIntelliJ() -> URL? {
        for bundleID in intelliJBundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }
        for path in intelliJFallbackPaths {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        return nil
    }

    /// Opens the given folder as a project in IntelliJ IDEA.
    /// Throws `LaunchError.appNotFound` if IntelliJ IDEA isn't installed/locatable.
    func openInIntelliJ(_ folderURL: URL) throws {
        guard let appURL = locateIntelliJ() else {
            throw LaunchError.appNotFound
        }
        NSWorkspace.shared.open(
            [folderURL],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                print("Failed to open IntelliJ IDEA: \(error.localizedDescription)")
            }
        }
    }

    enum LaunchError: LocalizedError {
        case appNotFound

        var errorDescription: String? {
            switch self {
            case .appNotFound:
                return "IntelliJ IDEA could not be found on this Mac."
            }
        }
    }
}
