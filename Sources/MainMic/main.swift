import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = MicController()
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = StatusMenu(controller: controller)
        statusMenu = menu
        controller.onChange = { [weak menu] in menu?.refresh() }
        controller.start()

        // Re-assert after sleep: Bluetooth reconnects on wake and AirPods
        // frequently grab the input again.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.controller.audioChanged() }
        }

        // Turn on Launch at Login the first time so the priority survives reboots.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didOfferLaunchAtLogin") {
            defaults.set(true, forKey: "didOfferLaunchAtLogin")
            try? SMAppService.mainApp.register()
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
