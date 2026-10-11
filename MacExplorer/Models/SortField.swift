import Foundation

/// Sortable columns available in a pane's file table.
enum SortField: String, CaseIterable {
    case name
    case size
    case date
    case kind
}

enum SortOrder {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}
