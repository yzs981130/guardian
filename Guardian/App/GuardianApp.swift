import SwiftUI

@main
struct GuardianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProcessStore()

    var body: some Scene {
        // Main window – closed independently; app stays alive via MenuBarExtra
        Window("Guardian", id: "main-window") {
            MainWindowView()
                .environmentObject(store)
                .frame(minWidth: 750, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Show Guardian Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.identifier?.rawValue == "main-window" {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        // Menu bar – always present even when main window is closed
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            Image(systemName: "shield.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}
