import AppKit
import SwiftUI

enum AddEditMode {
    case add
    case edit(ProcessConfig)
}

struct AddEditProcessView: View {
    @EnvironmentObject var store: ProcessStore
    @Environment(\.dismiss) var dismiss

    let mode: AddEditMode

    @State private var name: String = ""
    @State private var label: String = ""
    @State private var executablePath: String = ""
    @State private var argumentsText: String = ""
    @State private var workingDirectory: String = ""
    @State private var keepAlive: Bool = true
    @State private var runAtLoad: Bool = true
    @State private var stdoutPath: String = ""
    @State private var stderrPath: String = ""
    @State private var envVars: [(key: String, value: String)] = []
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var labelEditedManually = false
    @State private var logPathEditedManually = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                executableSection
                behaviorSection
                logsSection
                environmentSection
                if let err = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .textFieldStyle(.roundedBorder)
            .navigationTitle(isEditing ? "Edit Process" : "Add Process")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || label.isEmpty || executablePath.isEmpty || isSaving)
                }
            }
        }
        .frame(minWidth: 520, maxWidth: 620, minHeight: 480, maxHeight: 640)
        .onAppear { populateFields() }
    }

    // MARK: - Form sections

    private var identitySection: some View {
        Section("Identity") {
            TextField("Display Name (e.g. My Server)", text: $name)
                .onChange(of: name) { _, newName in
                    guard !labelEditedManually else { return }
                    // Auto-suggest a label from the name
                    let slug = newName
                        .lowercased()
                        .components(separatedBy: .alphanumerics.inverted)
                        .filter { !$0.isEmpty }
                        .joined(separator: "-")
                    label = "com.guardian.\(slug)"
                    guard !logPathEditedManually else { return }
                    let defaultLogPath = ProcessConfig.defaultLogPath(for: label)
                    let previousStdout = stdoutPath
                    stdoutPath = defaultLogPath
                    if stderrPath.isEmpty || stderrPath == previousStdout {
                        stderrPath = defaultLogPath
                    }
                }
            TextField(
                "Label (reverse-DNS, e.g. com.guardian.myserver)",
                text: $label,
                onEditingChanged: { editing in
                    if editing {
                        labelEditedManually = true
                    }
                }
            )
                .font(.system(.body, design: .monospaced))
        }
    }

    private var executableSection: some View {
        Section("Executable") {
            HStack {
                TextField("Path to executable (absolute)", text: $executablePath)
                    .font(.system(.body, design: .monospaced))
                Button("Browse…") { browseForExecutable() }
            }
            TextField("Arguments (space-separated)", text: $argumentsText)
                .font(.system(.body, design: .monospaced))
            HStack {
                TextField("Working Directory (optional)", text: $workingDirectory)
                    .font(.system(.body, design: .monospaced))
                Button("Browse…") { browseForDirectory() }
            }
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Keep Alive – auto-restart process on crash or exit", isOn: $keepAlive)
            Toggle("Run at Login – start this process when you log in", isOn: $runAtLoad)
        } header: {
            Text("Behavior")
        } footer: {
            if keepAlive {
                Text("Stopping a Keep-Alive process sends SIGTERM; launchd will restart it. Use \"Disable\" to permanently stop it until manually re-enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logsSection: some View {
        Section("Logs") {
            HStack {
                TextField("Stdout log path", text: $stdoutPath, onEditingChanged: { editing in
                    if editing { logPathEditedManually = true }
                })
                .font(.system(.caption, design: .monospaced))
                Button("Browse…") {
                    logPathEditedManually = true
                    browseForLogFile(binding: $stdoutPath)
                }
            }
            HStack {
                TextField("Stderr log path (leave same as stdout to merge)", text: $stderrPath)
                    .font(.system(.caption, design: .monospaced))
                Button("Browse…") { browseForLogFile(binding: $stderrPath) }
            }
        }
    }

    private var environmentSection: some View {
        Section {
            ForEach(envVars.indices, id: \.self) { idx in
                HStack {
                    TextField("KEY", text: Binding(
                        get: { envVars[idx].key },
                        set: { envVars[idx].key = $0 }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 140)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: Binding(
                        get: { envVars[idx].value },
                        set: { envVars[idx].value = $0 }
                    ))
                    .font(.system(.body, design: .monospaced))
                    Button { envVars.remove(at: idx) } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                envVars.append((key: "", value: ""))
            } label: {
                Label("Add Variable", systemImage: "plus")
            }
        } header: {
            Text("Environment Variables")
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var config: ProcessConfig
        switch mode {
        case .add:
            config = ProcessConfig()
        case .edit(let existing):
            config = existing
        }

        config.name = name
        config.label = label
        config.executablePath = executablePath
        config.arguments = argumentsText
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        config.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
        config.keepAlive = keepAlive
        config.runAtLoad = runAtLoad
        let resolvedStdout = stdoutPath.isEmpty ? ProcessConfig.defaultLogPath(for: label) : stdoutPath
        config.standardOutPath = resolvedStdout
        config.standardErrorPath = stderrPath.isEmpty ? resolvedStdout : stderrPath
        config.environmentVariables = Dictionary(
            uniqueKeysWithValues: envVars
                .filter { !$0.key.isEmpty }
                .map { ($0.key, $0.value) }
        )

        do {
            switch mode {
            case .add:  try await store.addProcess(config)
            case .edit: try await store.updateProcess(config)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Populate on edit

    private func populateFields() {
        if case .edit(let config) = mode {
            name = config.name
            label = config.label
            executablePath = config.executablePath
            argumentsText = config.arguments.joined(separator: " ")
            workingDirectory = config.workingDirectory ?? ""
            keepAlive = config.keepAlive
            runAtLoad = config.runAtLoad
            stdoutPath = config.standardOutPath
            stderrPath = config.standardErrorPath
            envVars = config.environmentVariables
                .sorted(by: { $0.key < $1.key })
                .map { (key: $0.key, value: $0.value) }
            labelEditedManually = true
            logPathEditedManually = true
        } else {
            let defaultLabel = "com.guardian.new-process"
            label = defaultLabel
            stdoutPath = ProcessConfig.defaultLogPath(for: defaultLabel)
            stderrPath = stdoutPath
        }
    }

    // MARK: - File browser helpers

    private func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                executablePath = url.path
            }
        }
    }

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                workingDirectory = url.path
            }
        }
    }

    private func browseForLogFile(binding: Binding<String>) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "process.log"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                binding.wrappedValue = url.path
            }
        }
    }
}
