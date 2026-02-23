import Foundation

struct PlistGenerator {

    /// Generates the XML plist data for a LaunchAgent.
    static func generate(for config: ProcessConfig) throws -> Data {
        var dict: [String: Any] = [
            "Label": config.label,
            "ProgramArguments": [config.executablePath] + config.arguments,
            "StandardOutPath": config.standardOutPath,
            "StandardErrorPath": config.standardErrorPath,
            "RunAtLoad": config.runAtLoad,
            "KeepAlive": config.keepAlive,
        ]
        if let wd = config.workingDirectory, !wd.isEmpty {
            dict["WorkingDirectory"] = wd
        }
        if !config.environmentVariables.isEmpty {
            dict["EnvironmentVariables"] = config.environmentVariables
        }
        return try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }

    /// Writes the plist to ~/Library/LaunchAgents/<label>.plist.
    /// Also ensures the log file directory exists.
    static func writePlist(for config: ProcessConfig) throws {
        // Ensure ~/Library/LaunchAgents/ directory exists
        let launchAgentsDir = config.plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: launchAgentsDir,
            withIntermediateDirectories: true
        )
        // Ensure log directory exists (launchd won't create it)
        let logDir = URL(fileURLWithPath: config.standardOutPath)
            .deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: logDir,
            withIntermediateDirectories: true
        )
        // Write plist atomically
        let data = try generate(for: config)
        try data.write(to: config.plistURL, options: .atomic)
    }

    /// Removes the plist file. Fails silently if it doesn't exist.
    static func removePlist(for config: ProcessConfig) {
        try? FileManager.default.removeItem(at: config.plistURL)
    }
}
