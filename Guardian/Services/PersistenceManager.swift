import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    private var storageURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        return appSupport
            .appendingPathComponent("com.guardian.app")
            .appendingPathComponent("processes.json")
    }

    func load() throws -> [ProcessConfig] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }
        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder().decode([ProcessConfig].self, from: data)
    }

    func save(_ configs: [ProcessConfig]) throws {
        let dir = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configs)
        try data.write(to: storageURL, options: .atomic)
    }
}
