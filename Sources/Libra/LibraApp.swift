import AppKit
import SwiftUI

@main
struct LibraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Libra", id: "main") {
            LibraView()
        }
        .defaultSize(width: 900, height: 445)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }

    init() {
        AppInfoProvider.printStartupInfo()
        Log.shared.setup()
        Paths.ensureDirectory(Paths.applicationSupportDirectory())
        Paths.ensureLogsDirectory()
        NSApp?.setActivationPolicy(.regular)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp?.mainMenu = buildMenu()

        if let iconURL = Resources.url(forResource: "AppIcon", withExtension: "icns"),
            let image = NSImage(contentsOf: iconURL)
        {
            NSApp?.applicationIconImage = image
        }

        for window in NSApp?.windows ?? [] {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .black
            window.minSize = NSSize(width: 780, height: 430)
        }
    }

    private func buildMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Libra")

        let appMenu = NSMenu(title: "Libra")
        appMenu.addItem(withTitle: "About Libra", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(
            withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let servicesItem = appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = NSMenu(title: "Services")
        NSApp?.servicesMenu = servicesItem.submenu
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Hide Libra", action: #selector(NSApp?.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others", action: #selector(NSApp?.hideOtherApplications(_:)),
            keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All", action: #selector(NSApp?.unhideAllApplications(_:)),
            keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit Libra", action: #selector(NSApp?.terminate(_:)), keyEquivalent: "q")

        let appMenuItem = NSMenuItem(title: "Libra", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            withTitle: "Open Folder…", action: #selector(openFolder), keyEquivalent: "o")
        let selectItem = NSMenuItem(
            title: "Select Videos…", action: #selector(selectFiles), keyEquivalent: "o")
        selectItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(selectItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: "Cancel", action: #selector(cancelWork), keyEquivalent: ".")
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            withTitle: "Undo Last Run", action: #selector(undoLastRun), keyEquivalent: "z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(
            withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m")
        windowMenu.addItem(
            withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp?.windowsMenu = windowMenu

        return mainMenu
    }

    @objc func showAbout() {
        let info = AppInfoProvider.current()
        let alert = NSAlert()
        alert.messageText = info.name
        alert.informativeText = [
            "Version \(info.version)",
            info.license,
            info.organization,
            info.architecture,
            info.copyright,
        ].joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func checkForUpdates() {
        Task {
            let info = AppInfoProvider.current()
            let result = await Updates.checkForUpdates(currentVersion: info.version)
            let alert = NSAlert()
            alert.alertStyle = result.error != nil ? .warning : .informational
            if let error = result.error {
                alert.messageText = "Update check failed"
                alert.informativeText = error
            } else if result.updateAvailable {
                alert.messageText = "Update available: \(result.latestVersion)"
                alert.informativeText =
                    "You have \(result.currentVersion).\(result.downloadURL.map { "\n\n\($0)" } ?? "")"
            } else {
                alert.messageText = "You're up to date"
                alert.informativeText = "Current version: \(result.currentVersion)"
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func showSettings() {
        // Routed through SwiftUI's public `openSettings` environment action —
        // received by LibraView, which owns a live view hierarchy.
        NotificationCenter.default.post(name: LibraCommands.openSettings, object: nil)
    }

    @objc func openFolder() {
        NotificationCenter.default.post(name: LibraCommands.openFolder, object: nil)
    }

    @objc func selectFiles() {
        NotificationCenter.default.post(name: LibraCommands.selectFiles, object: nil)
    }

    @objc func undoLastRun(_ sender: Any? = nil) {
        if NSApp?.keyWindow?.firstResponder is NSTextView {
            NSApp?.sendAction(Selector(("undo:")), to: nil, from: sender)
            return
        }
        NotificationCenter.default.post(name: LibraCommands.undoLastRun, object: nil)
    }

    @objc func cancelWork() {
        NotificationCenter.default.post(name: LibraCommands.cancelWork, object: nil)
    }
}
