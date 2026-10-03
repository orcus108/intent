import AppKit
import ApplicationServices
import Carbon

struct InsertionTarget {
    let pid: pid_t
    let element: AXUIElement

    static func capture() -> InsertionTarget? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        guard subrole as? String != kAXSecureTextFieldSubrole else { return nil }
        // Do not paste into buttons, links, or an unknown focus destination.
        var writable = DarwinBoolean(false)
        let selectedWritable = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &writable) == .success && writable.boolValue
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard selectedWritable || [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role as? String ?? "") else { return nil }
        return InsertionTarget(pid: app.processIdentifier, element: element)
    }

    func isStillFocused() -> Bool {
        guard let current = Self.capture() else { return false }
        return current.pid == pid && CFEqual(current.element, element)
    }

    func insert(_ text: String) -> Bool {
        guard isStillFocused() else { return false }
        if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success { return true }
        // Some editors do not implement AX text writes; fall back to a normal paste.
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ownChange = pasteboard.changeCount
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard pasteboard.changeCount == ownChange else { return }
            pasteboard.clearContents()
            let items = saved.map { values -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in values { item.setData(data, forType: type) }
                return item
            }
            pasteboard.writeObjects(items)
        }
        return true
    }
}

@MainActor
final class Hotkey {
    private var global: Any?
    private var local: Any?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var registeredKey: EventHotKeyRef?
    private var carbonHandler: EventHandlerRef?
    private var held = false
    private var lastStatus = (false, "Checking shortcut…")
    var useControl = false {
        didSet {
            guard oldValue != useControl else { return }
            if held { held = false; onStop?() }
            if let registeredKey { UnregisterEventHotKey(registeredKey) }
            registeredKey = nil
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            if let tap { CFMachPortInvalidate(tap) }
            source = nil; tap = nil
            install()
        }
    }
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onCancel: (() -> Void)?
    var onStatus: ((Bool, String) -> Void)?

    func reportStatus() { onStatus?(lastStatus.0, lastStatus.1) }
    private func setStatus(_ available: Bool, _ message: String) {
        lastStatus = (available, message)
        reportStatus()
    }

    func install() {
        guard registeredKey == nil, tap == nil else { return }
        if let global { NSEvent.removeMonitor(global) }
        if let local { NSEvent.removeMonitor(local) }
        global = nil; local = nil
        // Observe Escape and modifier releases. The registered hotkey itself does
        // not depend on Accessibility or Input Monitoring permission.
        global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handle(event) }
        }
        local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            let suppress = MainActor.assumeIsolated { self?.handle(event) == true }
            return suppress ? nil : event
        }
        if carbonHandler == nil {
            var types = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
            ]
            InstallEventHandler(GetApplicationEventTarget(), { _, event, info in
                guard let event, let info else { return OSStatus(eventNotHandledErr) }
                var key = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                      key.signature == 0x494E544E, key.id == 1 else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<Hotkey>.fromOpaque(info).takeUnretainedValue()
                MainActor.assumeIsolated {
                    if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
                        if !owner.held { owner.held = true; owner.onStart?() }
                    } else if owner.held { owner.held = false; owner.onStop?() }
                }
                return noErr
            }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &carbonHandler)
        }
        var registration = OSStatus(eventNotHandledErr)
        if carbonHandler != nil {
            registration = RegisterEventHotKey(UInt32(kVK_Space), UInt32(useControl ? controlKey : optionKey),
                                                EventHotKeyID(signature: 0x494E544E, id: 1), GetApplicationEventTarget(),
                                                OptionBits(kEventHotKeyExclusive), &registeredKey)
        }
        if registration == noErr {
            setStatus(true, "Global shortcut registered")
            return
        }
        if AXIsProcessTrusted() {
            let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            let callback: CGEventTapCallBack = { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<Hotkey>.fromOpaque(info).takeUnretainedValue()
                var suppress = false
                MainActor.assumeIsolated {
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    } else if let native = NSEvent(cgEvent: event) { suppress = owner.handle(native) }
                }
                return suppress ? nil : Unmanaged.passUnretained(event)
            }
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: CGEventMask(mask), callback: callback,
                                    userInfo: Unmanaged.passUnretained(self).toOpaque())
            if let tap {
                source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                setStatus(true, "Global shortcut available through Accessibility")
                return
            }
        }
        setStatus(false, registration == OSStatus(eventHotKeyExistsErr)
                  ? "Shortcut is reserved by macOS or another app. Choose another shortcut, or enable Accessibility for the fallback."
                  : "Global shortcut could not be registered (\(registration)). Choose another shortcut.")
    }

    private func handle(_ event: NSEvent) -> Bool {
        if event.type == .keyDown && event.keyCode == 53 { onCancel?(); return false }
        let modifier: NSEvent.ModifierFlags = useControl ? .control : .option
        if held && ((event.type == .keyUp && event.keyCode == 49) || (event.type == .flagsChanged && !event.modifierFlags.contains(modifier))) {
            held = false; onStop?(); return true
        }
        let relevant = event.modifierFlags.intersection([.option, .control, .command, .shift])
        if event.type == .keyDown && event.keyCode == 49 && relevant == modifier {
            if !held && !event.isARepeat { held = true; onStart?() }
            return true
        }
        return false
    }
}
