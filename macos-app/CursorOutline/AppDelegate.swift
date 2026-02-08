import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private let overlayController = OverlayController()
  private let hotKeyManager = HotKeyManager()

  private var hotKeyHintText: String = "Hotkey: Control+Option+Command+F (hold)"
  private var hotKeyAvailable: Bool = true

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("CursorOutline: didFinishLaunching")

    // Keep it simple while we debug visibility: show a normal app in the Dock.
    // We can switch back to a menu-only agent app later.
    NSApp.setActivationPolicy(.regular)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.isVisible = true
    if let button = statusItem?.button {
      button.title = "CO"
      button.toolTip = "Cursor Outline"
      let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Cursor Outline")
      image?.isTemplate = true
      button.imagePosition = .imageLeading
      button.image = image
    }

    let menu = buildMenu()
    menu.delegate = self
    statusItem?.menu = menu
    statusMenu = menu

    overlayController.start()

    hotKeyManager.onPressed = { [weak self] in
      DispatchQueue.main.async {
        self?.overlayController.beginSpotlight()
      }
    }
    hotKeyManager.onReleased = { [weak self] in
      DispatchQueue.main.async {
        self?.overlayController.endSpotlight()
      }
    }

    registerHotKeyWithFallback()
    showOnboardingIfNeeded()
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
      updateHint(available: true, combo: primary.combo)
      return
    } catch {
      NSLog("CursorOutline: failed to register hotkey \(primary.combo): \(error)")
    }

    do {
      try hotKeyManager.register(keyCode: fallback.keyCode, modifiers: modifiers)
      updateHint(available: true, combo: fallback.combo)
      return
    } catch {
      updateHint(available: false, combo: primary.combo)
      NSLog("CursorOutline: failed to register hotkey \(fallback.combo): \(error)")
    }
  }

  private func showOnboardingIfNeeded() {
    let key = "suppressOnboarding.v2"
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: key) else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.presentOnboarding()
    }
  }

  private func presentOnboarding() {
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Cursor Outline is running"

    let hotkeyLine = hotKeyAvailable
      ? "\(hotKeyHintText)."
      : "\(hotKeyHintText). Another app or macOS already uses it."

    alert.informativeText = [
      "Menu bar icon: CO",
      hotkeyLine,
      "The display outline only appears when you have 2 or more (non-mirrored) displays, and only on the display containing the cursor.",
    ].joined(separator: "\n")

    alert.addButton(withTitle: "Test Spotlight")
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Don't show again")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      overlayController.beginSpotlight()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        self?.overlayController.endSpotlight()
      }
    } else if response == .alertThirdButtonReturn {
      UserDefaults.standard.set(true, forKey: "suppressOnboarding.v2")
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
  case outlineStatus = 3
}

