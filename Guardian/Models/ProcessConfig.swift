import Foundation

struct ProcessConfig: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var label: String
    var executablePath: String
    var arguments: [String]
    var workingDirectory: String?
    var environmentVariables: [String: String]
    var keepAlive: Bool
    var runAtLoad: Bool
    var standardOutPath: String
    var standardErrorPath: String

    // ~/Library/LaunchAgents/<label>.plist
    var plistURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    static func defaultLogPath(for label: String) -> String {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Guardian/\(label).log")
            .path
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        label: String = "",
        executablePath: String = "",
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environmentVariables: [String: String] = [:],
        keepAlive: Bool = true,
        runAtLoad: Bool = true,
        standardOutPath: String = "",
        standardErrorPath: String = ""
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.keepAlive = keepAlive
        self.runAtLoad = runAtLoad
        let logPath = standardOutPath.isEmpty ? Self.defaultLogPath(for: label) : standardOutPath
        self.standardOutPath = logPath
        self.standardErrorPath = standardErrorPath.isEmpty ? logPath : standardErrorPath
    }
}
