import SwiftUI

// MARK: - Status color helper (shared across views)
extension ProcessStatus {
    var color: Color {
        switch self {
        case .running:   return .green
        case .stopped:   return Color(NSColor.secondaryLabelColor)
        case .crashed:   return .red
        case .notLoaded: return .orange
        case .unknown:   return Color(NSColor.tertiaryLabelColor)
        }
    }
}
