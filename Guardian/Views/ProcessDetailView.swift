import SwiftUI

struct ProcessDetailView: View {
    @EnvironmentObject var store: ProcessStore
    let config: ProcessConfig

    @State private var showEditSheet = false
    @State private var selectedTab = 0
    @StateObject private var logWatcher = LogWatcher()

    private var status: ProcessStatus {
        store.statuses[config.id] ?? .unknown
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            TabView(selection: $selectedTab) {
                ProcessInfoView(config: config)
                    .tabItem { Label("Info", systemImage: "info.circle") }
                    .tag(0)
                LogView(watcher: logWatcher, logPath: config.standardOutPath)
                    .tabItem { Label("Logs", systemImage: "doc.text") }
                    .tag(1)
            }
        }
        .onAppear {
            logWatcher.start(watching: config.standardOutPath)
        }
        .onDisappear {
            logWatcher.stop()
        }
        .onChange(of: config.standardOutPath) { _, newPath in
            logWatcher.start(watching: newPath)
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditProcessView(mode: .edit(config))
                .environmentObject(store)
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
                .shadow(color: status.color.opacity(0.6), radius: status.isRunning ? 4 : 0)

            VStack(alignment: .leading, spacing: 1) {
                Text(config.name)
                    .font(.title3.bold())
                Text(status.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Control buttons
            controlButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var controlButtons: some View {
        let isRunning = status.isRunning
        let isNotLoaded = status == .notLoaded

        HStack(spacing: 6) {
            Button("Start") {
                Task {
                    do {
                        try await store.startProcess(config)
                    } catch {
                        store.errorMessage = error.localizedDescription
                    }
                }
            }
            .disabled(isRunning)

            Button("Stop") {
                Task {
                    do {
                        try await store.stopProcess(config)
                    } catch {
                        store.errorMessage = error.localizedDescription
                    }
                }
            }
            .disabled(!isRunning)

            Button("Restart") {
                Task {
                    do {
                        try await store.restartProcess(config)
                    } catch {
                        store.errorMessage = error.localizedDescription
                    }
                }
            }
            .disabled(!isRunning)

            Divider().frame(height: 20)

            if isNotLoaded {
                Button("Enable") {
                    Task {
                        do {
                            try await store.enableProcess(config)
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                }
            } else {
                Button("Disable") {
                    Task {
                        do {
                            try await store.disableProcess(config)
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            Button("Edit") { showEditSheet = true }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Info tab content

struct ProcessInfoView: View {
    let config: ProcessConfig

    var body: some View {
        Form {
            Section("Command") {
                LabeledContent("Executable", value: config.executablePath)
                if !config.arguments.isEmpty {
                    LabeledContent("Arguments") {
                        Text(config.arguments.joined(separator: " "))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
                if let wd = config.workingDirectory, !wd.isEmpty {
                    LabeledContent("Working Dir", value: wd)
                }
            }

            Section("Identity") {
                LabeledContent("Label", value: config.label)
                LabeledContent("Plist", value: config.plistURL.path)
            }

            Section("Behavior") {
                LabeledContent("Keep Alive") {
                    Text(config.keepAlive ? "Yes (auto-restart on crash)" : "No")
                        .foregroundStyle(config.keepAlive ? .primary : .secondary)
                }
                LabeledContent("Run at Login") {
                    Text(config.runAtLoad ? "Yes" : "No")
                        .foregroundStyle(config.runAtLoad ? .primary : .secondary)
                }
            }

            if !config.environmentVariables.isEmpty {
                Section("Environment") {
                    ForEach(config.environmentVariables.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }

            Section("Logs") {
                LabeledContent("Stdout", value: config.standardOutPath)
                if config.standardErrorPath != config.standardOutPath {
                    LabeledContent("Stderr", value: config.standardErrorPath)
                }
            }
        }
        .formStyle(.grouped)
    }
}
