import Foundation

enum ProcessStatus: Equatable {
    case running(pid: Int)
    case stopped
    case crashed(exitCode: Int)
    case notLoaded
    case unknown

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var displayString: String {
        switch self {
        case .running(let pid): return "Running (PID \(pid))"
        case .stopped:          return "Stopped"
        case .crashed(let code): return "Crashed (exit \(code))"
        case .notLoaded:        return "Not Loaded"
        case .unknown:          return "Unknown"
        }
    }

    var shortString: String {
        switch self {
        case .running:   return "Running"
        case .stopped:   return "Stopped"
        case .crashed:   return "Crashed"
        case .notLoaded: return "Not Loaded"
        case .unknown:   return "Unknown"
        }
    }

    // Build status from launchctl list output fields
    static func from(pid: Int?, lastExitStatus: Int, isLoaded: Bool) -> ProcessStatus {
        guard isLoaded else { return .notLoaded }
        if let pid, pid > 0 { return .running(pid: pid) }
        if lastExitStatus == 0 { return .stopped }
        return .crashed(exitCode: lastExitStatus)
    }
}
