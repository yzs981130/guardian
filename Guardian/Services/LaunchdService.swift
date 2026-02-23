import Foundation

enum LaunchdError: Error, LocalizedError {
    case commandFailed(Int32, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let msg):
            return "launchctl exited \(code): \(msg)"
        case .parseError(let msg):
            return "Status parse error: \(msg)"
        }
    }
}

/// All launchctl interactions. Uses `Foundation.Process` directly (no shell)
/// to avoid argument injection from user-supplied labels/paths.
actor LaunchdService {
    static let shared = LaunchdService()

    private var uid: String { String(getuid()) }
    private var domainTarget: String { "gui/\(uid)" }
    private func serviceTarget(_ label: String) -> String { "gui/\(uid)/\(label)" }

    // MARK: - Public API

    /// Register a plist with launchd. If already loaded, boots out first.
    func bootstrap(plistURL: URL) async throws {
        let label = plistURL.deletingPathExtension().lastPathComponent
        // Check if already loaded; bootout first to ensure we pick up plist changes
        let (_, _, isLoaded) = await queryStatus(label: label)
        if isLoaded {
            try? await bootout(label: label)
            // Brief pause for launchd to process
            try? await Task.sleep(for: .milliseconds(200))
        }
        try await run("bootstrap", domainTarget, plistURL.path)
    }

    /// Remove a service from launchd. Silently ignores "not found" errors.
    func bootout(label: String) async throws {
        // bootout can legitimately fail if not loaded; we treat that as a no-op
        try? await run("bootout", serviceTarget(label))
    }

    /// Kill any running instance and immediately start the service.
    func kickstart(label: String) async throws {
        try await run("kickstart", "-kp", serviceTarget(label))
    }

    /// Send SIGTERM to a running service.
    /// Note: if KeepAlive=true in the plist, launchd will restart it automatically.
    func stop(label: String) async throws {
        try await run("kill", "SIGTERM", serviceTarget(label))
    }

    /// Query PID, last exit status, and whether the service is loaded.
    func queryStatus(label: String) async -> (pid: Int?, lastExitStatus: Int, isLoaded: Bool) {
        guard let output = try? await runOutput("list", label),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return (nil, 0, false)
        }
        // launchctl list <label> returns an old-style plist
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ) as? [String: Any]
        else {
            return (nil, 0, false)
        }
        let pid = plist["PID"] as? Int
        let exitStatus = (plist["LastExitStatus"] as? Int) ?? 0
        return (pid, exitStatus, true)
    }

    // MARK: - Private Helpers

    private var launchctl: String { "/bin/launchctl" }

    @discardableResult
    private func run(_ args: String...) async throws -> String {
        try await runArgs(args)
    }

    @discardableResult
    private func runArgs(_ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchctl)
        process.arguments = args
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        // Async wait for termination
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown"
            throw LaunchdError.commandFailed(process.terminationStatus, errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private func runOutput(_ args: String...) async throws -> String {
        try await runArgs(args)
    }
}
