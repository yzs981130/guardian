import SwiftUI

struct ProcessListView: View {
    @EnvironmentObject var store: ProcessStore
    @Binding var selectedID: UUID?
    @Binding var showAddSheet: Bool

    var body: some View {
        List(store.processes, selection: $selectedID) { config in
            ProcessRowView(config: config)
                .tag(config.id)
                .contextMenu { contextMenu(for: config) }
        }
        .listStyle(.sidebar)
        .navigationTitle("Guardian")
        .overlay {
            if store.processes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shield.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No Processes")
                        .foregroundStyle(.secondary)
                    Button("Add First Process") { showAddSheet = true }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for config: ProcessConfig) -> some View {
        let status = store.statuses[config.id] ?? .unknown

        if status.isRunning {
            Button("Restart") { runAction { try await store.restartProcess(config) } }
            Button("Stop") { runAction { try await store.stopProcess(config) } }
            Divider()
            Button("Disable (bootout)") { runAction { try await store.disableProcess(config) } }
        } else if status == .notLoaded {
            Button("Enable (bootstrap)") { runAction { try await store.enableProcess(config) } }
        } else {
            Button("Start") { runAction { try await store.startProcess(config) } }
            Divider()
            Button("Disable (bootout)") { runAction { try await store.disableProcess(config) } }
        }
        Divider()
        Button("Remove", role: .destructive) {
            runAction { try await store.removeProcess(config) }
        }
    }

    private func runAction(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
