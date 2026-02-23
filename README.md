# Guardian

A macOS menu-bar app for keeping your terminal commands alive.

Guardian lets you register any shell command as a managed background process. It uses macOS's built-in **launchd** daemon to keep processes running — Guardian itself only monitors their status, it does not directly keep them alive. This means your processes survive Guardian crashes or restarts, and are managed by the most reliable process supervisor on the platform.

## Features

- **Persistent processes** — each process is backed by a `LaunchAgent` plist; launchd restarts it on crash (`KeepAlive`)
- **Menu bar** — lives exclusively in the menu bar (no Dock icon), shows per-process status at a glance
- **Main window** — `NavigationSplitView` with process list, detail panel, and real-time log viewer
- **Real-time logs** — tails `stdout`/`stderr` via `DispatchSource` (event-driven, no polling)
- **Per-process login** — `RunAtLoad` in the plist makes a process start at login, independently of Guardian
- **Guardian login item** — `SMAppService` registers Guardian itself to start at login
- **Status polling** — queries `launchctl list <label>` every 5 seconds; shows `running / stopped / crashed / notLoaded`
- **Disable without delete** — `bootout` temporarily stops a KeepAlive process without removing its plist

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac (Universal Binary)

## Installation

### Download (recommended)

1. Go to [Releases](https://github.com/yzs981130/guardian/releases/latest)
2. Download `Guardian-vX.Y.Z.zip`
3. Unzip and move `Guardian.app` to `/Applications`
4. First launch: **right-click → Open** to bypass Gatekeeper (unsigned build)

### Build from source

Prerequisites: Xcode 16+, Homebrew

```bash
git clone https://github.com/yzs981130/guardian.git
cd guardian
make setup   # installs xcodegen + generates Guardian.xcodeproj
make open    # opens in Xcode, then ⌘R to run
```

## Usage

### Add a process

1. Click the shield icon 🛡 in the menu bar → **Open**
2. Click **+** in the toolbar
3. Fill in:
   - **Display Name** — human-readable label (e.g. `My Server`)
   - **Label** — reverse-DNS identifier (e.g. `com.example.myserver`) — auto-suggested from name
   - **Executable** — absolute path to the binary (use **Browse…**)
   - **Arguments** — space-separated CLI arguments
   - **Working Directory** — optional
   - **Keep Alive** — restart automatically on crash/exit (default: on)
   - **Run at Login** — start this process at login (default: on)
4. Click **Save** — Guardian writes the plist to `~/Library/LaunchAgents/<label>.plist` and bootstraps it

### Stop vs Disable

| Action | Effect |
|--------|--------|
| **Stop** | Sends `SIGTERM`. If `KeepAlive=true`, launchd **restarts it** — this is intentional |
| **Disable** | Calls `launchctl bootout` — removes from launchd without deleting the plist. Process won't restart until re-enabled |
| **Remove** | Boots out and deletes the plist permanently |

### Log files

Logs are written to `~/Library/Logs/Guardian/<label>.log` by default (configurable per process). The **Logs** tab in the detail view tails the file in real time. Click **Load History** to see lines written before Guardian was opened.

### Login item

In **Settings**, toggle **Start Guardian at Login**. If macOS shows a yellow warning, click **Open System Settings…** and approve Guardian in **General → Login Items & Extensions**.

## Architecture

```
Guardian app
├── Monitors status via launchctl (5-second poll)       ← Guardian's role
└── launchd                                              ← actual process supervisor
    ├── ~/Library/LaunchAgents/com.guardian.*.plist
    └── Manages KeepAlive, RunAtLoad, log redirection
```

### Data flow

```
User adds process
  → PlistGenerator writes ~/Library/LaunchAgents/<label>.plist
  → LaunchdService: launchctl bootstrap gui/<uid> <plist>
  → launchd starts and owns the process
  → ProcessStore polls launchctl list <label> every 5 seconds
  → SwiftUI views update automatically via @Published
```

### Key design decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Process supervisor | launchd | Native macOS, survives app restarts, handles KeepAlive/RunAtLoad |
| App lifecycle | `LSUIElement=true` | Stable menu-bar-only mode; no Dock flicker |
| Menu bar | SwiftUI `MenuBarExtra` | macOS 13+ native scene type |
| Status monitoring | Poll `launchctl list` every 5s | launchd provides no push notifications |
| Log watching | `DispatchSource` `.write` event | Event-driven, no polling, immediate updates |
| Login item | `SMAppService.mainApp` | Modern macOS 13+ API, no helper bundle needed |
| Persistence | JSON in `~/Library/Application Support/com.guardian.app/` | Human-readable, no size limit |
| Project generation | xcodegen + `project.yml` | Reproducible, no binary `.pbxproj` in git |

## File structure

```
Guardian/
├── App/
│   ├── GuardianApp.swift        @main — declares Window + MenuBarExtra scenes
│   └── AppDelegate.swift        prevents quit on window close
├── Models/
│   ├── ProcessConfig.swift      Codable data model (id, label, executablePath, …)
│   ├── ProcessStatus.swift      enum: running(pid) / stopped / crashed(exitCode) / notLoaded
│   └── ProcessStore.swift       @MainActor ObservableObject, single source of truth
├── Services/
│   ├── LaunchdService.swift     actor wrapping launchctl bootstrap/bootout/kickstart/kill/list
│   ├── PlistGenerator.swift     writes ~/Library/LaunchAgents/<label>.plist
│   ├── LogWatcher.swift         DispatchSource file watcher → @Published lines
│   ├── LoginItemService.swift   SMAppService.mainApp register/unregister
│   └── PersistenceManager.swift JSON read/write for process config list
└── Views/
    ├── MenuBarView.swift         compact process list + Open/Quit buttons
    ├── MainWindowView.swift      NavigationSplitView root
    ├── ProcessListView.swift     sidebar list with context menus
    ├── ProcessRowView.swift      status dot + name
    ├── ProcessDetailView.swift   Info + Logs tabs, control buttons
    ├── AddEditProcessView.swift  sheet for create/edit
    ├── LogView.swift             scrollable monospaced log with auto-scroll
    ├── SettingsView.swift        Guardian login item toggle
    └── StatusColor.swift         ProcessStatus → SwiftUI Color extension
```

## Known limitations

- **Not App Store compatible** — App Sandbox is disabled (required to write `~/Library/LaunchAgents/` and run `launchctl`)
- **Unsigned** — release builds are unsigned. Right-click → Open on first launch to bypass Gatekeeper
- **No log rotation** — `LogWatcher` doesn't handle log file replacement (e.g. via `newsyslog`)
- **KeepAlive throttle** — launchd backs off exponentially (up to ~10s) before restarting a crashing process; status will show `crashed` during this window
- **Argument editor** — arguments are entered as a space-separated string; quoting/escaping is not handled

## CI / CD

| Trigger | Workflow | Result |
|---------|----------|--------|
| Push to `main` / PR | `.github/workflows/ci.yml` | Build verification (arm64 Release) |
| `git tag v*` | `.github/workflows/release.yml` | Build → zip → GitHub Release |

Releases are built with Xcode 16.2 on `macos-15` runners, unsigned (`CODE_SIGNING_ALLOWED=NO`).

To cut a release:

```bash
git tag v1.2.3
git push origin v1.2.3
```

## License

MIT
