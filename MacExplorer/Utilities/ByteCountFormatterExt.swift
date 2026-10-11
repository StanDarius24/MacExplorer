import Foundation

extension ByteCountFormatter {
    /// Shared formatter configured like Finder/Total Commander size columns.
    static let fileSize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
}
