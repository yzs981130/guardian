import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: ProcessStore
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
            processSection
            Divider()
            footerRow
        }
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Label("Guardian", systemImage: "shield.fill")
                .font(.headline)
            Spacer()
            Button("Open") {
                openWindow(id: "main-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Process list

    @ViewBuilder
    private var processSection: some View {
        if store.processes.isEmpty {
            Text("No processes configured")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(12)
        } else {
            ForEach(store.processes) { config in
                MenuBarProcessRow(config: config)
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Button {
                Task { await store.refreshAllStatuses() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Single process row in the menu bar panel

struct MenuBarProcessRow: View {
    @EnvironmentObject var store: ProcessStore
    let config: ProcessConfig

    private var status: ProcessStatus {
        store.statuses[config.id] ?? .unknown
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(config.name)
                .lineLimit(1)
            Spacer()
            Text(status.shortString)
                .font(.caption)
                .foregroundStyle(.secondary)
            menuButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var menuButton: some View {
        Menu {
            if status.isRunning {
                Button("Restart") { Task { try? await store.restartProcess(config) } }
                Button("Stop")    { Task { try? await store.stopProcess(config) } }
            } else {
                Button("Start")   { Task { try? await store.startProcess(config) } }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
