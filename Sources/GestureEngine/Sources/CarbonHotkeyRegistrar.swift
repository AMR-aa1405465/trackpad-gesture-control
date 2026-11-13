import Carbon.HIToolbox
import Foundation
import GestureCore

/// Registers system-wide keyboard shortcuts with Carbon's hotkey API. Needs no extra macOS
/// permission. A registered shortcut is CONSUMED: the frontmost app no longer receives it.
public final class CarbonHotkeyRegistrar: HotkeyRegistrar {
    private let lock = NSLock()
    private var refs: [EventHotKeyRef] = []
    private var hotkeysByID: [UInt32: Hotkey] = [:]
    private var onPress: ((Hotkey) -> Void)?
    private var handlerInstalled = false
    private var nextID: UInt32 = 1

    // The C callback cannot capture context, so it reaches the live instance through this.
    private static weak var active: CarbonHotkeyRegistrar?

    public init() {}

    private static let modifierMasks: [String: UInt32] = [
        "command": UInt32(cmdKey), "control": UInt32(controlKey),
        "option": UInt32(optionKey), "shift": UInt32(shiftKey),
    ]

    @discardableResult
    public func register(_ hotkeys: [Hotkey], onPress: @escaping (Hotkey) -> Void) -> [HotkeyFailure] {
        unregisterAll()
        installHandlerIfNeeded()
        lock.lock(); defer { lock.unlock() }
        self.onPress = onPress
        var failures: [HotkeyFailure] = []
        for hotkey in hotkeys {
            guard let code = KeyCodes.code(for: hotkey.key) else {
                failures.append(HotkeyFailure(hotkey: hotkey, reason: "unknown key")); continue
            }
            let mods = hotkey.modifiers.reduce(UInt32(0)) { $0 | (Self.modifierMasks[$1] ?? 0) }
            let id = nextID; nextID += 1
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(code), mods, EventHotKeyID(signature: 0x7470_676B, id: id),
                GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                refs.append(ref); hotkeysByID[id] = hotkey
            } else {
                let why = status == OSStatus(eventHotKeyExistsErr)
                    ? "already used by macOS or another app" : "OS error \(status)"
                failures.append(HotkeyFailure(hotkey: hotkey, reason: why))
            }
        }
        return failures
    }

    public func unregisterAll() {
        lock.lock(); defer { lock.unlock() }
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll(); hotkeysByID.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        CarbonHotkeyRegistrar.active = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            CarbonHotkeyRegistrar.active?.fire(id.id)
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func fire(_ id: UInt32) {
        lock.lock(); let hotkey = hotkeysByID[id]; let callback = onPress; lock.unlock()
        if let hotkey = hotkey { callback?(hotkey) }
    }
}
