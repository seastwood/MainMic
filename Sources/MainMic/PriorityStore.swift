import Foundation

/// A microphone MainMic has seen at least once. Remembered by its Core Audio UID,
/// which stays the same across unplug/replug and reboots.
struct KnownDevice: Codable, Equatable {
    var uid: String
    var name: String
    var isBuiltIn: Bool
    /// When false the device is never auto-selected, even if nothing else is connected.
    var enabled: Bool = true
}

/// The ordered priority list (index 0 wins), persisted in UserDefaults.
final class PriorityStore {
    private let defaultsKey = "priorityList.v1"
    private let defaults: UserDefaults

    private(set) var devices: [KnownDevice] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([KnownDevice].self, from: data) {
            devices = saved
        }
    }

    /// Adds newly seen devices and refreshes names. The built-in mic goes to the
    /// top the first time it is seen; everything else (AirPods, USB, etc.) starts
    /// at the bottom so it never steals priority until you move it up.
    /// Returns true if the list changed.
    @discardableResult
    func register(_ connected: [InputDevice]) -> Bool {
        var changed = false
        for device in connected {
            if let i = devices.firstIndex(where: { $0.uid == device.uid }) {
                if devices[i].name != device.name {
                    devices[i].name = device.name
                    changed = true
                }
            } else {
                let known = KnownDevice(uid: device.uid, name: device.name, isBuiltIn: device.isBuiltIn)
                if device.isBuiltIn {
                    devices.insert(known, at: 0)
                } else {
                    devices.append(known)
                }
                changed = true
            }
        }
        if changed { save() }
        return changed
    }

    /// The highest-priority enabled device that is currently connected.
    func preferred(among connected: [InputDevice]) -> InputDevice? {
        for known in devices where known.enabled {
            if let match = connected.first(where: { $0.uid == known.uid }) { return match }
        }
        return nil
    }

    func moveToTop(_ uid: String) { move(uid) { _ in 0 } }
    func moveToBottom(_ uid: String) { move(uid) { _ in self.devices.count - 1 } }
    func moveUp(_ uid: String) { move(uid) { max($0 - 1, 0) } }
    func moveDown(_ uid: String) { move(uid) { min($0 + 1, self.devices.count - 1) } }

    func setEnabled(_ uid: String, _ enabled: Bool) {
        guard let i = devices.firstIndex(where: { $0.uid == uid }) else { return }
        devices[i].enabled = enabled
        save()
    }

    func forget(_ uid: String) {
        devices.removeAll { $0.uid == uid }
        save()
    }

    private func move(_ uid: String, to destination: (Int) -> Int) {
        guard let from = devices.firstIndex(where: { $0.uid == uid }) else { return }
        let target = destination(from)
        let item = devices.remove(at: from)
        let to = min(max(target, 0), devices.count)
        devices.insert(item, at: to)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
