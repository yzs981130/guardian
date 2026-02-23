import SwiftUI

struct ProcessRowView: View {
    @EnvironmentObject var store: ProcessStore
    let config: ProcessConfig

    private var status: ProcessStatus {
        store.statuses[config.id] ?? .unknown
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 9, height: 9)
                .shadow(color: status.color.opacity(0.6), radius: status.isRunning ? 3 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.body)
                Text(status.shortString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
