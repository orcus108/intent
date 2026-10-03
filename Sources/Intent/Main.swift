import AppKit
import SwiftUI
import Combine

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--check-hotkey") {
            MainActor.assumeIsolated {
                let app = NSApplication.shared
                app.setActivationPolicy(.accessory)
                let hotkey = Hotkey()
                hotkey.onStatus = { available, message in print("\(available ? "AVAILABLE" : "UNAVAILABLE"): \(message)") }
                hotkey.useControl = UserDefaults.standard.bool(forKey: "useControl")
                hotkey.install(); hotkey.reportStatus()
                print("Accessibility: \(AXIsProcessTrusted())")
                print("Shortcut: \(hotkey.useControl ? "Control" : "Option") + Space")
            }
            return
        }
        if CommandLine.arguments.contains("--transcribe"), let path = CommandLine.arguments.last {
            Task {
                do {
                    let engine = try await LocalSpeechEngine.prepare { fraction in
                        fputs("Model download: \(Int(fraction * 100))%\n", stderr)
                    }
                    let start = Date()
                    let text = try await engine.transcribe(audio: URL(fileURLWithPath: path), vocabulary: "")
                    print(text)
                    fputs(String(format: "Transcription: %.2fs\n", Date().timeIntervalSince(start)), stderr)
                    exit(0)
                } catch { fputs("Transcription error: \(error)\n", stderr); exit(1) }
            }
            RunLoop.main.run()
            return
        }
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DictationModel!
    private var window: NSWindow!
    private var pill: NSPanel!
    private var item: NSStatusItem!
    private var subscriptions = Set<AnyCancellable>()
    private var horizontalFraction: CGFloat = {
        guard UserDefaults.standard.object(forKey: "pillHorizontalFraction") != nil else { return 0.5 }
        let saved = UserDefaults.standard.double(forKey: "pillHorizontalFraction")
        return saved.isFinite ? CGFloat(min(1, max(0, saved))) : 0.5
    }()
    private var dragOrigin: (mouseX: CGFloat, centerX: CGFloat)?
    private var pillPositioned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = DictationModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Intent — voice playground"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainView(model: model)); window.center()
        pill = FloatingPillPanel(contentRect: NSRect(x: 0, y: 0, width: 64, height: 24), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        pill.title = "Intent floating pill"
        pill.backgroundColor = .clear; pill.isOpaque = false; pill.hasShadow = false
        pill.level = .floating; pill.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        pill.hidesOnDeactivate = false
        pill.contentView = PillHostingView(rootView: RecordingView(model: model,
            onDrag: { [weak self] in self?.dragPill() },
            onDragEnd: { [weak self] in self?.finishDraggingPill() }))
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Intent")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Intent", action: #selector(openWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Start / finish recording", action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(withTitle: "Re-centre pill", action: #selector(recentrePill), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Intent", action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        model.showWindow = { [weak self] in self?.openWindow() }
        model.$phase.combineLatest(model.$showPill).sink { [weak self] phase, visible in
            self?.updatePill(phase: phase, visible: visible)
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification).sink { [weak self] _ in
            guard let self else { return }
            self.updatePill(phase: self.model.phase, visible: self.model.showPill)
        }.store(in: &subscriptions)
        openWindow()
        if LocalSpeechEngine.isInstalled { model.loadModel() }
    }

    private func updatePill(phase: DictationModel.Phase, visible: Bool) {
        let active = phase == .recording || phase == .processing
        guard visible || active else { pill.orderOut(nil); return }
        let size: NSSize
        switch phase {
        case .recording: size = NSSize(width: 184, height: 34)
        case .processing: size = NSSize(width: 150, height: 30)
        default: size = NSSize(width: 64, height: 24)
        }
        if let screen = (pillPositioned ? pill.screen : nil) ?? NSScreen.main {
            let center = clampedCenter(screen.visibleFrame.minX + horizontalFraction * screen.visibleFrame.width,
                                       size: size, screen: screen)
            pill.setFrame(NSRect(x: center - size.width / 2,
                                 y: screen.visibleFrame.minY + 24, width: size.width, height: size.height), display: true)
            pillPositioned = true
        }
        pill.orderFrontRegardless()
    }

    private func clampedCenter(_ center: CGFloat, size: NSSize, screen: NSScreen) -> CGFloat {
        let margin = size.width / 2 + 8
        return min(screen.visibleFrame.maxX - margin, max(screen.visibleFrame.minX + margin, center))
    }

    private func dragPill() {
        guard let screen = pill.screen ?? NSScreen.main else { return }
        let mouseX = NSEvent.mouseLocation.x
        if dragOrigin == nil { dragOrigin = (mouseX, pill.frame.midX) }
        guard let origin = dragOrigin else { return }
        let center = clampedCenter(origin.centerX + mouseX - origin.mouseX, size: pill.frame.size, screen: screen)
        pill.setFrameOrigin(NSPoint(x: center - pill.frame.width / 2, y: pill.frame.minY))
        horizontalFraction = (center - screen.visibleFrame.minX) / max(1, screen.visibleFrame.width)
    }

    private func finishDraggingPill() {
        guard dragOrigin != nil else { return }
        dragOrigin = nil
        UserDefaults.standard.set(Double(horizontalFraction), forKey: "pillHorizontalFraction")
    }

    @objc private func openWindow() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openWindow()
        return true
    }
    @objc private func recentrePill() {
        dragOrigin = nil
        horizontalFraction = 0.5
        UserDefaults.standard.set(0.5, forKey: "pillHorizontalFraction")
        updatePill(phase: model.phase, visible: model.showPill)
    }
    @objc private func toggleRecording() { if model.phase == .recording { model.stop() } else { model.start() } }
    @objc private func quit() { model.cancel(); NSApp.terminate(nil) }
}

// Clicking the pill must leave keyboard focus and the insertion target in the user's editor.
final class FloatingPillPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PillHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
