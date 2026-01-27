import AppKit
import SwiftUI

@Observable
final class StatusItemManager: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "leaf.circle.fill",
                                   accessibilityDescription: "DodoTidy")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the right-click context menu
        setupContextMenu()

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 380)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        // Monitor clicks outside the popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    private func setupContextMenu() {
        let menu = NSMenu()

        // Header with app icon and name
        let headerItem = NSMenuItem()
        let headerView = NSHostingView(rootView: MenuBarHeaderView())
        headerView.frame = NSRect(x: 0, y: 0, width: 220, height: 80)
        headerItem.view = headerView
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(title: "Open DodoTidy", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // GitHub repo link
        let githubItem = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        githubItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        menu.addItem(githubItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit DodoTidy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = nil // We'll show it manually on right-click
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Show context menu on right-click
            showContextMenu()
        } else {
            // Show popover on left-click
            togglePopover(sender)
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        // Header with app icon and name
        let headerItem = NSMenuItem()
        let headerView = NSHostingView(rootView: MenuBarHeaderView())
        headerView.frame = NSRect(x: 0, y: 0, width: 220, height: 85)
        headerItem.view = headerView
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(title: "Open DodoTidy", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // GitHub repo link
        let githubItem = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        githubItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        menu.addItem(githubItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit DodoTidy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("DodoTidy") || $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open a new window if none exists
            for window in NSApp.windows {
                if window.contentView != nil && !(window.contentView is NSHostingView<MenuBarView>) {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/bluewave-labs/DodoTidy") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

// MARK: - Menu Bar Header View

struct MenuBarHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // App icon from bundle
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("DodoTidy")
                        .font(.system(size: 14, weight: .semibold))

                    Text("System Cleaner & Monitor")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text("© 2026 Gorkem Cetin")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Link(destination: URL(string: "https://github.com/bluewave-labs/DodoTidy")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                    Text("github.com/bluewave-labs/DodoTidy")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 220, alignment: .leading)
    }
}
