import AppKit
import Carbon

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private let overlayController = OverlayController()
  private let hotKeyManager = HotKeyManager()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem?.button {
      let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Cursor Outline")
      image?.isTemplate = true
      button.image = image
    }
    statusItem?.menu = buildMenu()

    overlayController.start()

    hotKeyManager.onPressed = { [weak self] in
      Task { @MainActor in
        self?.overlayController.beginSpotlight()
      }
    }
    hotKeyManager.onReleased = { [weak self] in
      Task { @MainActor in
        self?.overlayController.endSpotlight()
      }
    }

    do {
      try hotKeyManager.register(
        keyCode: UInt32(kVK_ANSI_F),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
      )
    } catch {
      NSLog("CursorOutline: failed to register hotkey: \(error)")
    }
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
    enabledItem.target = self
    enabledItem.state = overlayController.isEnabled ? .on : .off
    menu.addItem(enabledItem)

    let infoItem = NSMenuItem(title: overlayController.outlineStatusText, action: nil, keyEquivalent: "")
    infoItem.isEnabled = false
    menu.addItem(infoItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Cursor Outline", action: #selector(quit(_:)), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @objc private func toggleEnabled(_ sender: NSMenuItem) {
    overlayController.isEnabled.toggle()
    sender.state = overlayController.isEnabled ? .on : .off

    if let menu = statusItem?.menu, menu.items.count >= 2 {
      menu.items[1].title = overlayController.outlineStatusText
    }
  }

  @objc private func quit(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}
