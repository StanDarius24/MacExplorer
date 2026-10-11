import Foundation

extension DateFormatter {
    /// Shared formatter for the "Date Modified" column.
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
