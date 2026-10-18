import CoreAudio
import Foundation

/// A Core Audio device that can record (has at least one input channel).
struct InputDevice: Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: UInt32

    var isBuiltIn: Bool { transport == kAudioDeviceTransportTypeBuiltIn }

    var isBluetooth: Bool {
        transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}

/// Thin wrapper over the Core Audio HAL calls the app needs.
enum AudioSystem {
    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    // MARK: Devices

    /// All currently connected devices with input channels, excluding hidden and
    /// transient aggregate devices that apps create behind the scenes.
    static func inputDevices() -> [InputDevice] {
        allDeviceIDs().compactMap { id in
            guard inputChannelCount(id) > 0, !isHidden(id) else { return nil }
            guard let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { return nil }
            if uid.hasPrefix("CADefaultDeviceAggregate") { return nil }
            let name = stringProperty(id, kAudioObjectPropertyName) ?? uid
            let transport = uint32Property(id, kAudioDevicePropertyTransportType) ?? 0
            return InputDevice(id: id, uid: uid, name: name, transport: transport)
        }
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        (uint32Property(id, kAudioDevicePropertyIsHidden) ?? 0) != 0
    }

    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func uint32Property(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    // MARK: Default input

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    @discardableResult
    static func setDefaultInputDevice(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var device = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        return AudioObjectSetPropertyData(systemObject, &addr, 0, nil, size, &device) == noErr
    }

    // MARK: Change notifications

    /// Calls `handler` on the main queue whenever the device list or the
    /// default input device changes.
    static func observeChanges(_ handler: @escaping () -> Void) {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
            var addr = address(selector)
            AudioObjectAddPropertyListenerBlock(systemObject, &addr, DispatchQueue.main) { _, _ in handler() }
        }
    }
}
