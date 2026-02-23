import AppKit
import Foundation
import ServiceManagement

final class LoginItemService {
    static let shared = LoginItemService()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Register or unregister Guardian as a login item.
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opens System Settings to the Login Items panel so the user can approve.
    func openLoginItemsSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}
