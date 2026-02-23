import Combine
import Foundation
import ServiceManagement

/// Central state coordinator. Single source of truth for all process configs and statuses.
/// All mutations must happen on the MainActor.
@MainActor
final class ProcessStore: ObservableObject {
    @Published var processes: [ProcessConfig] = []
    @Published var statuses: [UUID: ProcessStatus] = [:]
    @Published var isGuardianLoginItem: Bool = false
    @Published var errorMessage: String?

    private let persistence = PersistenceManager.shared
    private let launchd = LaunchdService.shared
    private let loginItem = LoginItemService.shared
    private var pollingTask: Task<Void, Never>?

    // MARK: - Startup

    func onAppLaunch() async {
        do {
            processes = try persistence.load()
        } catch {
            errorMessage = "Failed to load saved processes: \(error.localizedDescription)"
        }
        isGuardianLoginItem = loginItem.isEnabled
        await refreshAllStatuses()
        startPolling()
    }

    // MARK: - Process CRUD

    func addProcess(_ config: ProcessConfig) async throws {
        try PlistGenerator.writePlist(for: config)
        try await launchd.bootstrap(plistURL: config.plistURL)
        processes.append(config)
        try persistence.save(processes)
        let status = await fetchStatus(for: config)
        statuses[config.id] = status
    }

    func updateProcess(_ config: ProcessConfig) async throws {
        guard let idx = processes.firstIndex(where: { $0.id == config.id }) else { return }
        let old = processes[idx]

        // Take down the old service before rewriting the plist
        try await launchd.bootout(label: old.label)
        if old.label != config.label {
            PlistGenerator.removePlist(for: old)
        }
        try PlistGenerator.writePlist(for: config)
        try await launchd.bootstrap(plistURL: config.plistURL)
        processes[idx] = config
        try persistence.save(processes)
        let status = await fetchStatus(for: config)
        statuses[config.id] = status
    }

    func removeProcess(_ config: ProcessConfig) async throws {
        try await launchd.bootout(label: config.label)
        PlistGenerator.removePlist(for: config)
        processes.removeAll { $0.id == config.id }
        statuses.removeValue(forKey: config.id)
        try persistence.save(processes)
    }

    // MARK: - Process Control

    func startProcess(_ config: ProcessConfig) async throws {
        // If not loaded (e.g. after manual removal), bootstrap first
        let (_, _, isLoaded) = await launchd.queryStatus(label: config.label)
        if !isLoaded {
            try PlistGenerator.writePlist(for: config)
            try await launchd.bootstrap(plistURL: config.plistURL)
        } else {
            try await launchd.kickstart(label: config.label)
        }
        try? await Task.sleep(for: .milliseconds(600))
        statuses[config.id] = await fetchStatus(for: config)
    }

    func stopProcess(_ config: ProcessConfig) async throws {
        // Sends SIGTERM. If KeepAlive=true, launchd will restart automatically.
        // This is intentional – the plist controls restart policy.
        try await launchd.stop(label: config.label)
        try? await Task.sleep(for: .milliseconds(600))
        statuses[config.id] = await fetchStatus(for: config)
    }

    /// Boots out (disables) without removing the plist. Process won't restart until re-enabled.
    func disableProcess(_ config: ProcessConfig) async throws {
        try await launchd.bootout(label: config.label)
        statuses[config.id] = .notLoaded
    }

    /// Re-bootstraps a disabled (notLoaded) process.
    func enableProcess(_ config: ProcessConfig) async throws {
        try await launchd.bootstrap(plistURL: config.plistURL)
        try? await Task.sleep(for: .milliseconds(600))
        statuses[config.id] = await fetchStatus(for: config)
    }

    func restartProcess(_ config: ProcessConfig) async throws {
        try await launchd.kickstart(label: config.label)
        try? await Task.sleep(for: .milliseconds(600))
        statuses[config.id] = await fetchStatus(for: config)
    }

    // MARK: - Status Refresh

    func refreshAllStatuses() async {
        await withTaskGroup(of: (UUID, ProcessStatus).self) { group in
            for config in processes {
                group.addTask {
                    let status = await self.fetchStatus(for: config)
                    return (config.id, status)
                }
            }
            for await (id, status) in group {
                statuses[id] = status
            }
        }
    }

    private func fetchStatus(for config: ProcessConfig) async -> ProcessStatus {
        let (pid, exitStatus, isLoaded) = await launchd.queryStatus(label: config.label)
        return ProcessStatus.from(pid: pid, lastExitStatus: exitStatus, isLoaded: isLoaded)
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.refreshAllStatuses()
            }
        }
    }

    // MARK: - Login Item

    func setGuardianLoginItem(enabled: Bool) throws {
        try loginItem.setEnabled(enabled)
        isGuardianLoginItem = loginItem.isEnabled
    }

    var guardianLoginItemStatus: SMAppService.Status {
        loginItem.status
    }

    func openLoginItemSettings() {
        loginItem.openLoginItemsSettings()
    }
}
