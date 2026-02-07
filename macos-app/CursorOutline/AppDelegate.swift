import AppKit
import Carbon

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private let overlayController = OverlayController()
  private let hotKeyManager = HotKeyManager()
  private var hotKeyHintText: String = "Hotkey: Control+Option+Command+F (hold)"
  private var hotKeyAvailable: Bool = true

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem?.isVisible = true
    if let button = statusItem?.button {
      let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Cursor Outline")
      image?.isTemplate = true
      button.title = "CO"
      button.imagePosition = .imageLeading
      button.image = image
      statusItem?.length = NSStatusItem.variableLength
      button.toolTip = "Cursor Outline"
    }
    let menu = buildMenu()
    menu.delegate = self
    statusItem?.menu = menu
    statusMenu = menu

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
      hotKeyAvailable = false
      hotKeyHintText = "Hotkey unavailable (Control+Option+Command+F in use)"
      if let menu = statusMenu, let hintItem = menu.item(withTag: MenuTag.hotkeyHint.rawValue) {
        hintItem.title = hotKeyHintText
      }
      NSLog("CursorOutline: failed to register hotkey: \(error)")
    }

    maybeShowOnboarding()
  }

  func menuWillOpen(_ menu: NSMenu) {
    guard menu == statusMenu else { return }
    if let enabledItem = menu.item(withTag: MenuTag.enabled.rawValue) {
      enabledItem.state = overlayController.isEnabled ? .on : .off
    }
    if let hintItem = menu.item(withTag: MenuTag.hotkeyHint.rawValue) {
      hintItem.title = hotKeyHintText
    }
    if let outlineItem = menu.item(withTag: MenuTag.outlineStatus.rawValue) {
      outlineItem.title = overlayController.outlineStatusText
    }
  }

  private func maybeShowOnboarding() {
    let key = "didShowOnboarding.v1"
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: key) else { return }
    defaults.set(true, forKey: key)

    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Cursor Outline is running"

    let hotkeyLine = hotKeyAvailable
      ? "Hold Control + Option + Command + F to spotlight the cursor."
      : "Hotkey unavailable. Another app or macOS already uses it."

    alert.informativeText = [
      "Look for the \"CO\" menu bar icon to access settings.",
      hotkeyLine,
      "The display outline only appears when you have 2 or more (non-mirrored) displays, and only on the display containing the cursor.",
    ].joined(separator: "\n")

    alert.addButton(withTitle: "Test Spotlight")
    alert.addButton(withTitle: "OK")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      overlayController.beginSpotlight()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        Task { @MainActor in
          self?.overlayController.endSpotlight()
        }
      }
    }
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
    enabledItem.target = self
    enabledItem.state = overlayController.isEnabled ? .on : .off
    enabledItem.tag = MenuTag.enabled.rawValue
    menu.addItem(enabledItem)

    let hintItem = NSMenuItem(title: hotKeyHintText, action: nil, keyEquivalent: "")
    hintItem.isEnabled = false
    hintItem.tag = MenuTag.hotkeyHint.rawValue
    menu.addItem(hintItem)

    let outlineItem = NSMenuItem(title: overlayController.outlineStatusText, action: nil, keyEquivalent: "")
    outlineItem.isEnabled = false
    outlineItem.tag = MenuTag.outlineStatus.rawValue
    menu.addItem(outlineItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Cursor Outline", action: #selector(quit(_:)), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @objc private func toggleEnabled(_ sender: NSMenuItem) {
    overlayController.isEnabled.toggle()
    sender.state = overlayController.isEnabled ? .on : .off

    if let menu = statusMenu,
       let outlineItem = menu.item(withTag: MenuTag.outlineStatus.rawValue) {
      outlineItem.title = overlayController.outlineStatusText
    }
  }

  @objc private func quit(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}

private enum MenuTag: Int {
  case enabled = 1
  case hotkeyHint = 2
  case outlineStatus = 3
}
