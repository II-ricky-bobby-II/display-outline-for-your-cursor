import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private let overlayController = OverlayController()
  private let hotKeyManager = HotKeyManager()

  private var hotKeyHintText: String = "Hotkey: Control+Option+Command+F (hold)"
  private var hotKeyEventText: String = "Hotkey event: none"
  private var hotKeyAvailable: Bool = true

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("CursorOutline: didFinishLaunching")

    // Keep behavior consistent with a lightweight menu-bar utility.
    NSApp.setActivationPolicy(.accessory)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.isVisible = true
    if let button = statusItem?.button {
      button.title = ""
      button.toolTip = "Cursor Outline"
      let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Cursor Outline")
      image?.isTemplate = true
      button.imagePosition = .imageOnly
      button.image = image
    }

    let menu = buildMenu()
    menu.delegate = self
    statusItem?.menu = menu
    statusMenu = menu

    overlayController.start()

    hotKeyManager.onPressed = { [weak self] in
      NSLog("CursorOutline: hotkey pressed")
      DispatchQueue.main.async {
        self?.hotKeyEventText = "Hotkey event: pressed"
        self?.overlayController.beginSpotlight()
      }
    }
    hotKeyManager.onReleased = { [weak self] in
      NSLog("CursorOutline: hotkey released")
      DispatchQueue.main.async {
        self?.hotKeyEventText = "Hotkey event: released"
        self?.overlayController.endSpotlight()
      }
    }

    registerHotKeyWithFallback()
  }

  func menuWillOpen(_ menu: NSMenu) {
    guard menu == statusMenu else { return }
    if let enabledItem = menu.item(withTag: MenuTag.enabled.rawValue) {
      enabledItem.state = overlayController.isEnabled ? .on : .off
    }
    if let hintItem = menu.item(withTag: MenuTag.hotkeyHint.rawValue) {
      hintItem.title = hotKeyHintText
    }
    if let hotKeyEventItem = menu.item(withTag: MenuTag.hotkeyEvent.rawValue) {
      hotKeyEventItem.title = hotKeyEventText
    }
    if let outlineItem = menu.item(withTag: MenuTag.outlineStatus.rawValue) {
      outlineItem.title = overlayController.outlineStatusText
    }
    if let diagnosticsItem = menu.item(withTag: MenuTag.diagnostics.rawValue) {
      diagnosticsItem.title = overlayController.diagnosticsText
    }
  }

  private func registerHotKeyWithFallback() {
    hotKeyAvailable = true

    let modifiers: UInt32 = UInt32(cmdKey | optionKey | controlKey)
    let primary: (keyCode: UInt32, combo: String) = (UInt32(kVK_ANSI_F), "Control+Option+Command+F")
    let fallback: (keyCode: UInt32, combo: String) = (UInt32(kVK_ANSI_G), "Control+Option+Command+G")

    func updateHint(available: Bool, combo: String) {
      hotKeyAvailable = available
      hotKeyHintText = available ? "Hotkey: \(combo) (hold)" : "Hotkey unavailable (\(combo) in use)"
      if let menu = statusMenu, let hintItem = menu.item(withTag: MenuTag.hotkeyHint.rawValue) {
        hintItem.title = hotKeyHintText
      }
    }

    do {
      try hotKeyManager.register(keyCode: primary.keyCode, modifiers: modifiers)
      NSLog("CursorOutline: registered hotkey \(primary.combo)")
      hotKeyEventText = "Hotkey event: registered \(primary.combo)"
      updateHint(available: true, combo: primary.combo)
      return
    } catch {
      NSLog("CursorOutline: failed to register hotkey \(primary.combo): \(error)")
    }

    do {
      try hotKeyManager.register(keyCode: fallback.keyCode, modifiers: modifiers)
      NSLog("CursorOutline: registered hotkey \(fallback.combo)")
      hotKeyEventText = "Hotkey event: registered \(fallback.combo)"
      updateHint(available: true, combo: fallback.combo)
      return
    } catch {
      updateHint(available: false, combo: primary.combo)
      hotKeyEventText = "Hotkey event: unavailable"
      NSLog("CursorOutline: failed to register hotkey \(fallback.combo): \(error)")
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

    let hotKeyEventItem = NSMenuItem(title: hotKeyEventText, action: nil, keyEquivalent: "")
    hotKeyEventItem.isEnabled = false
    hotKeyEventItem.tag = MenuTag.hotkeyEvent.rawValue
    menu.addItem(hotKeyEventItem)

    let outlineItem = NSMenuItem(title: overlayController.outlineStatusText, action: nil, keyEquivalent: "")
    outlineItem.isEnabled = false
    outlineItem.tag = MenuTag.outlineStatus.rawValue
    menu.addItem(outlineItem)

    let diagnosticsItem = NSMenuItem(title: overlayController.diagnosticsText, action: nil, keyEquivalent: "")
    diagnosticsItem.isEnabled = false
    diagnosticsItem.tag = MenuTag.diagnostics.rawValue
    menu.addItem(diagnosticsItem)

    menu.addItem(.separator())

    let testItem = NSMenuItem(title: "Test Spotlight", action: #selector(testSpotlight(_:)), keyEquivalent: "")
    testItem.target = self
    menu.addItem(testItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Cursor Outline", action: #selector(quit(_:)), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @objc private func toggleEnabled(_ sender: NSMenuItem) {
    overlayController.isEnabled.toggle()
    sender.state = overlayController.isEnabled ? .on : .off

    if let menu = statusMenu, let outlineItem = menu.item(withTag: MenuTag.outlineStatus.rawValue) {
      outlineItem.title = overlayController.outlineStatusText
    }
  }

  @objc private func testSpotlight(_ sender: Any?) {
    hotKeyEventText = "Hotkey event: Test Spotlight clicked"
    overlayController.beginSpotlight()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.overlayController.endSpotlight()
    }
  }

  @objc private func quit(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}

private enum MenuTag: Int {
  case enabled = 1
  case hotkeyHint = 2
  case hotkeyEvent = 3
  case outlineStatus = 4
  case diagnostics = 5
}
