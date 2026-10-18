import Foundation
import os

/// Keeps the system default input pinned to the highest-priority connected mic.
///
/// macOS (and AirPods in particular) can switch the default input at any moment:
/// on connect, when Bluetooth renegotiates, on wake, or when the AirPods' HFP
/// profile comes up a second or two after the device appears. So we react to
/// every Core Audio change, re-check a few times shortly after each one, and
/// also run a slow safety-net timer.
@MainActor
final class MicController {
    struct Switch {
        let from: String
        let to: String
        let date: Date
    }

    let store = PriorityStore()
    private(set) var connected: [InputDevice] = []
    private(set) var lastSwitch: Switch?
    var onChange: (() -> Void)?

    var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: "paused") }
        set {
            UserDefaults.standard.set(newValue, forKey: "paused")
            enforce()
        }
    }

    private let log = Logger(subsystem: "com.seastwood.mainmic", category: "enforce")
    private var followUps: [DispatchWorkItem] = []
    private var safetyTimer: Timer?

    func start() {
        AudioSystem.observeChanges { [weak self] in
            Task { @MainActor in self?.audioChanged() }
        }
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.enforce() }
        }
        safetyTimer?.tolerance = 1
        audioChanged()
    }

    /// Called for device connects/disconnects, default-input changes and wake.
    func audioChanged() {
        enforce()
        // Bluetooth devices often grab the default input again shortly after
        // connecting; re-check over the next few seconds to win that race.
        followUps.forEach { $0.cancel() }
        followUps = [0.25, 0.75, 1.5, 3, 6].map { delay in
            let item = DispatchWorkItem { [weak self] in
                Task { @MainActor in self?.enforce() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    /// The device currently set as the system default input.
    var currentInput: InputDevice? {
        guard let id = AudioSystem.defaultInputDeviceID() else { return nil }
        return connected.first { $0.id == id }
    }

    func enforce() {
        let devices = AudioSystem.inputDevices()
        let listChanged = store.register(devices)
        let connectedChanged = devices != connected
        connected = devices

        if !isPaused, let target = store.preferred(among: devices),
           AudioSystem.defaultInputDeviceID() != target.id {
            let previous = currentInput?.name ?? "none"
            if AudioSystem.setDefaultInputDevice(target.id) {
                log.info("Switched input \(previous, privacy: .public) -> \(target.name, privacy: .public)")
                lastSwitch = Switch(from: previous, to: target.name, date: Date())
            } else {
                log.error("Failed to set default input to \(target.name, privacy: .public)")
            }
            onChange?()
            return
        }

        if listChanged || connectedChanged { onChange?() }
    }

    // MARK: Priority edits (each one re-applies immediately)

    func moveToTop(_ uid: String) { store.moveToTop(uid); enforce(); onChange?() }
    func moveUp(_ uid: String) { store.moveUp(uid); enforce(); onChange?() }
    func moveDown(_ uid: String) { store.moveDown(uid); enforce(); onChange?() }
    func moveToBottom(_ uid: String) { store.moveToBottom(uid); enforce(); onChange?() }
    func setEnabled(_ uid: String, _ on: Bool) { store.setEnabled(uid, on); enforce(); onChange?() }
    func forget(_ uid: String) { store.forget(uid); enforce(); onChange?() }
}
