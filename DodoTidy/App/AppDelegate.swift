import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemManager: StatusItemManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemManager = StatusItemManager()
        statusItemManager?.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar even if main window is closed
        return false
    }
}
