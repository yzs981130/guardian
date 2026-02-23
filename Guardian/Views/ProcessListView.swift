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
            Button("Restart") { Task { try? await store.restartProcess(config) } }
            Button("Stop")    { Task { try? await store.stopProcess(config) } }
            Divider()
            Button("Disable (bootout)") { Task { try? await store.disableProcess(config) } }
        } else if status == .notLoaded {
            Button("Enable (bootstrap)") { Task { try? await store.enableProcess(config) } }
        } else {
            Button("Start")   { Task { try? await store.startProcess(config) } }
            Divider()
            Button("Disable (bootout)") { Task { try? await store.disableProcess(config) } }
        }
        Divider()
        Button("Remove", role: .destructive) {
            Task { try? await store.removeProcess(config) }
        }
    }
}
