import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kick off data loading and status polling on the main actor
        Task { @MainActor in
            // ProcessStore is owned by GuardianApp @StateObject, but we need a reference.
            // The store calls onAppLaunch() from the SwiftUI init path via .task modifier
            // on MainWindowView, so nothing is needed here for the store.
        }
    }

    // Keep the app alive when the last window is closed.
    // With LSUIElement=YES the app never quits on window close anyway, but this is belt-and-suspenders.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // If somehow the app gets a reopen event (e.g. Dock click), open the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == "main-window" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
