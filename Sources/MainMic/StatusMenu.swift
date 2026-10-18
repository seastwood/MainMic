import AppKit
import ServiceManagement

/// The menu bar icon and its menu. The menu is rebuilt every time it opens so
/// it always reflects what is plugged in right now.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let controller: MicController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    init(controller: MicController) {
        self.controller = controller
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateIcon()
    }

    func refresh() {
        updateIcon()
        rebuild()
    }

    private func updateIcon() {
        // A handheld "stage" mic, so it isn't confused with the macOS mic-in-use indicator.
        let symbol = controller.isPaused ? "pause.circle" : "music.mic"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MainMic")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "MainMic — input: \(controller.currentInput?.name ?? "none")"
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        controller.enforce()
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()

        let current = controller.currentInput
        menu.addItem(disabled("Input: \(current?.name ?? "None")"))
        if controller.isPaused {
            menu.addItem(disabled("Auto-switching paused"))
        } else if let last = controller.lastSwitch {
            let time = DateFormatter.localizedString(from: last.date, dateStyle: .none, timeStyle: .short)
            menu.addItem(disabled("Last fix: \(last.from) → \(last.to) at \(time)"))
        }
        menu.addItem(.separator())

        menu.addItem(disabled("Microphone Priority (top wins)"))
        for (index, device) in controller.store.devices.enumerated() {
            menu.addItem(deviceItem(device, rank: index + 1, isCurrent: device.uid == current?.uid))
        }
        menu.addItem(.separator())

        let pause = action("Pause Auto-Switching", #selector(togglePause))
        pause.state = controller.isPaused ? .on : .off
        menu.addItem(pause)

        let login = action("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(action("Open Sound Settings…", #selector(openSoundSettings)))
        menu.addItem(.separator())
        menu.addItem(action("Quit MainMic", #selector(quit), key: "q"))
    }

    private func deviceItem(_ device: KnownDevice, rank: Int, isCurrent: Bool) -> NSMenuItem {
        let isConnected = controller.connected.contains { $0.uid == device.uid }
        let item = NSMenuItem(title: "\(rank). \(device.name)", action: nil, keyEquivalent: "")
        item.state = isCurrent ? .on : .off

        var notes: [String] = []
        if !isConnected { notes.append("not connected") }
        if !device.enabled { notes.append("never use") }
        if !notes.isEmpty || !isConnected {
            let title = NSMutableAttributedString(string: "\(rank). \(device.name)")
            if !notes.isEmpty {
                title.append(NSAttributedString(
                    string: "  — \(notes.joined(separator: ", "))",
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
            }
            item.attributedTitle = title
        }

        let sub = NSMenu()
        sub.autoenablesItems = false
        let last = controller.store.devices.count
        sub.addItem(action("Make Top Priority", #selector(moveToTop(_:)), uid: device.uid, enabled: rank > 1))
        sub.addItem(action("Move Up", #selector(moveUp(_:)), uid: device.uid, enabled: rank > 1))
        sub.addItem(action("Move Down", #selector(moveDown(_:)), uid: device.uid, enabled: rank < last))
        sub.addItem(action("Move to Bottom", #selector(moveToBottom(_:)), uid: device.uid, enabled: rank < last))
        sub.addItem(.separator())
        let never = action("Never Use This Mic", #selector(toggleEnabled(_:)), uid: device.uid)
        never.state = device.enabled ? .off : .on
        sub.addItem(never)
        if !isConnected {
            sub.addItem(action("Forget Device", #selector(forget(_:)), uid: device.uid))
        }
        item.submenu = sub
        return item
    }

    // MARK: Item helpers

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(
        _ title: String, _ selector: Selector, key: String = "", uid: String? = nil, enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.representedObject = uid
        item.isEnabled = enabled
        return item
    }

    // MARK: Actions

    @objc private func moveToTop(_ sender: NSMenuItem) { if let uid = deviceUID(sender) { controller.moveToTop(uid) } }
    @objc private func moveUp(_ sender: NSMenuItem) { if let uid = deviceUID(sender) { controller.moveUp(uid) } }
    @objc private func moveDown(_ sender: NSMenuItem) { if let uid = deviceUID(sender) { controller.moveDown(uid) } }
    @objc private func moveToBottom(_ sender: NSMenuItem) { if let uid = deviceUID(sender) { controller.moveToBottom(uid) } }
    @objc private func forget(_ sender: NSMenuItem) { if let uid = deviceUID(sender) { controller.forget(uid) } }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        guard let uid = deviceUID(sender),
              let device = controller.store.devices.first(where: { $0.uid == uid }) else { return }
        controller.setEnabled(uid, !device.enabled)
    }

    @objc private func togglePause() {
        controller.isPaused.toggle()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nMove MainMic.app to /Applications and try again, or add it in System Settings → General → Login Items."
            alert.runModal()
        }
    }

    @objc private func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func deviceUID(_ sender: NSMenuItem) -> String? { sender.representedObject as? String }
}
