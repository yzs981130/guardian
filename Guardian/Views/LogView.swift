import SwiftUI

struct LogView: View {
    @ObservedObject var watcher: LogWatcher
    let logPath: String
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logContent
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("\(watcher.lines.count) lines")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            Button("Load History") {
                watcher.loadHistory(path: logPath)
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            Button("Clear") {
                watcher.lines.removeAll()
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Log content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if watcher.lines.isEmpty {
                        Text("No log output yet…")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(10)
                    } else {
                        ForEach(Array(watcher.lines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 1)
                                .id(idx)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: watcher.lines.count) { _, count in
                guard autoScroll, count > 0 else { return }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
    }
}
