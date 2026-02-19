import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?

  private let overlayController = OverlayController()
  private let hotKeyManager = HotKeyManager()
  private let settingsStore = AppSettingsStore.shared
  private let launchAtLoginManager = LaunchAtLoginManager()
  private let diagnosticsExporter = DiagnosticsExporter()

  private var preferencesWindowController: PreferencesWindowController?

  private var settings: AppSettings = .defaults
  private var hotKeyStatusText: String = "Hotkey: Unconfigured"
  private var hotKeyAvailable = false
  private var activeHotKey: HotKeyConfig?
  private var lastDiagnosticsArchiveName: String?

  func applicationDidFinishLaunching(_ notification: Notification) {
    settings = settingsStore.load()
    AppLogger.shared.log(.info, "Cursor Outline launched")

    NSApp.setActivationPolicy(.accessory)

    configureStatusItem()
    configureOverlay()
    configureHotKeyCallbacks()

    _ = applyHotKeyRegistration()
    syncLaunchAtLoginPreference(showAlertOnError: false)
  }

  func menuWillOpen(_ menu: NSMenu) {
    guard menu == statusMenu else { return }

    if let enabledItem = menu.item(withTag: MenuTag.enabled.rawValue) {
      enabledItem.state = overlayController.isEnabled ? .on : .off
    }

    if let hotKeyItem = menu.item(withTag: MenuTag.hotkeyStatus.rawValue) {
      hotKeyItem.title = hotKeyStatusText
    }

    if let outlineItem = menu.item(withTag: MenuTag.outlineStatus.rawValue) {
      outlineItem.title = overlayController.outlineStatusText
    }
  }

  private func configureStatusItem() {
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
  }

  private func configureOverlay() {
    overlayController.applyAppearance(
      thickness: settings.outlineThickness,
      color: settings.outlineColor,
      spotlightRadius: settings.spotlightRadius
    )
    overlayController.start()
  }

  private func configureHotKeyCallbacks() {
    hotKeyManager.onPressed = { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.overlayController.beginSpotlight()
        if let activeHotKey = self.activeHotKey {
          self.hotKeyStatusText = "Hotkey active: \(activeHotKey.displayString)"
        }
      }
    }

    hotKeyManager.onReleased = { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.overlayController.endSpotlight()
        self.refreshHotKeyStatusText()
      }
    }
  }

  @discardableResult
  private func applyHotKeyRegistration() -> HotKeyRegistrationOutcome {
    do {
      try hotKeyManager.register(hotKey: settings.hotKey)
      activeHotKey = settings.hotKey
      hotKeyAvailable = true
      refreshHotKeyStatusText()
      return .configured
    } catch let error as HotKeyRegistrationError {
      if error.isConflict {
        AppLogger.shared.log(.warning, "Configured hotkey conflict: \(settings.hotKey.displayString)")
      } else {
        AppLogger.shared.log(.error, "Failed to register configured hotkey: \(error.localizedDescription)")
      }
    } catch {
      AppLogger.shared.log(.error, "Failed to register configured hotkey: \(error.localizedDescription)")
    }

    do {
      try hotKeyManager.register(hotKey: .fallback)
      activeHotKey = .fallback
      hotKeyAvailable = true
      hotKeyStatusText = "Hotkey in use; temporarily using \(HotKeyConfig.fallback.displayString)"
      AppLogger.shared.log(.warning, "Using fallback hotkey: \(HotKeyConfig.fallback.displayString)")
      return .fallbackDueToConflict
    } catch {
      activeHotKey = nil
      hotKeyAvailable = false
      hotKeyStatusText = "Hotkey unavailable (in use). Change it in Preferences."
      AppLogger.shared.log(.warning, "No global hotkey available")
      return .unavailable
    }
  }

  private func refreshHotKeyStatusText() {
    if let activeHotKey {
      let suffix = activeHotKey == settings.hotKey ? "" : " (fallback)"
      hotKeyStatusText = "Hotkey: \(activeHotKey.displayString)\(suffix)"
    } else if hotKeyAvailable {
      hotKeyStatusText = "Hotkey: ready"
    } else {
      hotKeyStatusText = "Hotkey unavailable (in use). Change it in Preferences."
    }
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
    enabledItem.target = self
    enabledItem.state = overlayController.isEnabled ? .on : .off
    enabledItem.tag = MenuTag.enabled.rawValue
    menu.addItem(enabledItem)

    let hotKeyItem = NSMenuItem(title: hotKeyStatusText, action: nil, keyEquivalent: "")
    hotKeyItem.isEnabled = false
    hotKeyItem.tag = MenuTag.hotkeyStatus.rawValue
    menu.addItem(hotKeyItem)

    let outlineItem = NSMenuItem(title: overlayController.outlineStatusText, action: nil, keyEquivalent: "")
    outlineItem.isEnabled = false
    outlineItem.tag = MenuTag.outlineStatus.rawValue
    menu.addItem(outlineItem)

    menu.addItem(.separator())

    let testItem = NSMenuItem(title: "Test Spotlight", action: #selector(testSpotlight(_:)), keyEquivalent: "")
    testItem.target = self
    menu.addItem(testItem)

    let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences(_:)), keyEquivalent: ",")
    preferencesItem.target = self
    menu.addItem(preferencesItem)

    let exportItem = NSMenuItem(title: "Export Diagnostics...", action: #selector(exportDiagnostics(_:)), keyEquivalent: "")
    exportItem.target = self
    menu.addItem(exportItem)

    let reportItem = NSMenuItem(title: "Report Issue", action: #selector(reportIssue(_:)), keyEquivalent: "")
    reportItem.target = self
    menu.addItem(reportItem)

    let updatesItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
    updatesItem.target = self
    menu.addItem(updatesItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Cursor Outline", action: #selector(quit(_:)), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @objc private func toggleEnabled(_ sender: NSMenuItem) {
    overlayController.isEnabled.toggle()
    sender.state = overlayController.isEnabled ? .on : .off
  }

  @objc private func testSpotlight(_ sender: Any?) {
    overlayController.beginSpotlight()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.overlayController.endSpotlight()
      self?.refreshHotKeyStatusText()
    }
  }

  @objc private func openPreferences(_ sender: Any?) {
    if preferencesWindowController == nil {
      preferencesWindowController = PreferencesWindowController(settings: settings) { [weak self] newSettings in
        self?.applySettings(newSettings)
      }
    }

    preferencesWindowController?.update(settings: settings)
    preferencesWindowController?.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func applySettings(_ newSettings: AppSettings) {
    var next = newSettings.sanitized
    let hotKeyDidChange = next.hotKey != settings.hotKey

    if next.launchAtLogin != settings.launchAtLogin {
      do {
        try launchAtLoginManager.setEnabled(next.launchAtLogin)
      } catch {
        next.launchAtLogin = false
        presentLaunchAtLoginError(error)
      }
    }

    settings = next
    settingsStore.save(next)

    overlayController.applyAppearance(
      thickness: settings.outlineThickness,
      color: settings.outlineColor,
      spotlightRadius: settings.spotlightRadius
    )

    let hotKeyOutcome = applyHotKeyRegistration()
    if hotKeyDidChange {
      presentHotKeyOutcome(hotKeyOutcome)
    }
    preferencesWindowController?.update(settings: settings)
  }

  private func presentHotKeyOutcome(_ outcome: HotKeyRegistrationOutcome) {
    switch outcome {
    case .configured:
      return
    case .fallbackDueToConflict:
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Hotkey conflict detected"
      alert.informativeText = "That hotkey is already in use. Cursor Outline is temporarily using \(HotKeyConfig.fallback.displayString)."
      alert.addButton(withTitle: "OK")
      alert.runModal()
    case .unavailable:
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Hotkey unavailable"
      alert.informativeText = "Cursor Outline could not register any global hotkey. Choose another combination in Preferences."
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }

  private func syncLaunchAtLoginPreference(showAlertOnError: Bool) {
    guard settings.launchAtLogin else { return }

    do {
      try launchAtLoginManager.setEnabled(true)
    } catch {
      settings.launchAtLogin = false
      settingsStore.save(settings)
      if showAlertOnError {
        presentLaunchAtLoginError(error)
      }
    }
  }

  private func presentLaunchAtLoginError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Launch at login could not be enabled"

    if case let LaunchAtLoginError.notInApplications(currentPath) = error {
      var message = "Move Cursor Outline to /Applications, then try enabling launch at login again."
      if currentPath.contains("/DerivedData/") {
        message += "\n\nYou are currently running the app from Xcode's build output. Quit and launch the copy in /Applications."
      }
      message += "\n\nCurrent app path:\n\(currentPath)"
      alert.informativeText = message
      alert.addButton(withTitle: "Reveal App")
      alert.addButton(withTitle: "OK")
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
      }
    } else {
      alert.informativeText = error.localizedDescription
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }

    AppLogger.shared.log(.warning, "Launch-at-login toggle failed: \(error.localizedDescription)")
  }

  @objc private func exportDiagnostics(_ sender: Any?) {
    let savePanel = NSSavePanel()
    savePanel.canCreateDirectories = true
    savePanel.allowedContentTypes = [.zip]
    savePanel.nameFieldStringValue = diagnosticsExporter.defaultArchiveName()
    savePanel.title = "Export Diagnostics"

    guard savePanel.runModal() == .OK, let destination = savePanel.url else { return }

    do {
      let context = DiagnosticsContext(
        settings: settings,
        hotKeyStatus: hotKeyStatusText,
        outlineStatus: overlayController.outlineStatusText
      )
      try diagnosticsExporter.exportArchive(to: destination, context: context)
      lastDiagnosticsArchiveName = destination.lastPathComponent

      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "Diagnostics exported"
      alert.informativeText = destination.path
      alert.addButton(withTitle: "Reveal in Finder")
      alert.addButton(withTitle: "OK")
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        NSWorkspace.shared.activateFileViewerSelecting([destination])
      }
    } catch {
      AppLogger.shared.log(.error, "Diagnostics export failed: \(error.localizedDescription)")
      let alert = NSAlert(error: error)
      alert.runModal()
    }
  }

  @objc private func reportIssue(_ sender: Any?) {
    let url = diagnosticsExporter.issueURL(diagnosticsArchiveName: lastDiagnosticsArchiveName)
    NSWorkspace.shared.open(url)
  }

  @objc private func checkForUpdates(_ sender: Any?) {
    guard let url = URL(string: "https://github.com/II-ricky-bobby-II/display-outline-for-your-cursor/releases") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  @objc private func quit(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}

private enum MenuTag: Int {
  case enabled = 1
  case hotkeyStatus = 2
  case outlineStatus = 3
}

private enum HotKeyRegistrationOutcome {
  case configured
  case fallbackDueToConflict
  case unavailable
}
