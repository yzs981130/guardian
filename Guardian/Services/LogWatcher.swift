import Combine
import Foundation

/// Watches a log file for new content using DispatchSource (event-driven, no polling).
/// Publishes new lines as they arrive.
@MainActor
final class LogWatcher: ObservableObject {
    @Published var lines: [String] = []

    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private let maxLines = 2000

    /// Start watching the file at `path`. Only new content (written after this call) is shown.
    func start(watching path: String) {
        stop()
        lines = []
        ensureFileExists(at: path)

        guard let fh = FileHandle(forReadingAtPath: path) else { return }
        fh.seekToEndOfFile()
        fileHandle = fh

        let fd = fh.fileDescriptor
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )

        src.setEventHandler { [weak self, weak fh] in
            guard let fh else { return }
            let newData = fh.readDataToEndOfFile()
            guard !newData.isEmpty,
                  let text = String(data: newData, encoding: .utf8) else { return }
            let newLines = text
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            guard !newLines.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lines.append(contentsOf: newLines)
                if self.lines.count > self.maxLines {
                    self.lines.removeFirst(self.lines.count - self.maxLines)
                }
            }
        }

        src.setCancelHandler { [weak fh] in
            try? fh?.close()
        }

        self.source = src
        src.resume()
    }

    /// Load the last `lineCount` lines of history from the file.
    func loadHistory(path: String, lineCount: Int = 500) {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else { return }
        let all = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let tail = all.suffix(lineCount)
        lines = Array(tail)
    }

    func stop() {
        source?.cancel()
        source = nil
        fileHandle = nil
    }

    private func ensureFileExists(at path: String) {
        guard !FileManager.default.fileExists(atPath: path) else { return }
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: nil)
    }
}
