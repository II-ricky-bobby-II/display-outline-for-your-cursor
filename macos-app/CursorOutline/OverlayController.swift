import AppKit

final class OverlayController {
  private struct OutlineState: Equatable {
    let showOutline: Bool
    let activeDisplayID: CGDirectDisplayID?
    let windowCount: Int
  }

  var isEnabled: Bool = true {
    didSet {
      if !isEnabled {
        endSpotlight()
      }
      updateAllVisibility()
    }
  }

  var outlineStatusText: String {
    if !isEnabled { return "Outline: Off" }
    if !ScreenUtils.isMultiDisplayNonMirrored() { return "Outline: Hidden (single display)" }
    let liveIDs = Set(NSScreen.screens.compactMap(\.displayID))
    let knownIDs = Set(windowsByDisplayID.keys)
    if liveIDs != knownIDs { return "Outline: Syncing displays..." }
    if let cursorDisplayID = ScreenUtils.cursorScreen()?.displayID, windowsByDisplayID[cursorDisplayID] == nil {
      return "Outline: Syncing displays..."
    }
    return "Outline: On (multi display)"
  }

  var diagnosticsText: String {
    let screenIDs = NSScreen.screens.compactMap(\.displayID)
    let windowIDs = Array(windowsByDisplayID.keys)
    let cursorID = ScreenUtils.cursorScreen()?.displayID
    let cursorText = cursorID.map(String.init) ?? "nil"
    return "Diag: screens=\(screenIDs.count) windows=\(windowIDs.count) cursor=\(cursorText)"
  }

  private var windowsByDisplayID: [CGDirectDisplayID: OverlayPanel] = [:]

  private var screenObserver: Any?
  private var outlineTimer: Timer?
  private var spotlightTimer: Timer?

  private var spotlightActive = false
  private var lastOutlineState: OutlineState?

  func start() {
    refreshScreens()

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      NSLog("CursorOutline: screen parameter change notification received")
      self.refreshScreens()
      self.updateAllVisibility()
    }

    startOutlineLoop()
    updateAllVisibility()
  }

  func beginSpotlight() {
    guard isEnabled else { return }
    spotlightActive = true
    startSpotlightLoop()
  }

  func endSpotlight() {
    spotlightActive = false
    stopSpotlightLoop()
    for (_, window) in windowsByDisplayID {
      window.overlayView.setSpotlightVisible(false, animated: true)
    }
  }

  private func updateAllVisibility() {
    if !isEnabled {
      for (_, window) in windowsByDisplayID {
        window.overlayView.setOutlineVisible(false)
        window.overlayView.setSpotlightVisible(false, animated: false)
        window.orderOut(nil)
      }
      lastOutlineState = nil
      return
    }

    for (_, window) in windowsByDisplayID {
      window.orderFrontRegardless()
    }

    updateOutline(force: true)
  }

  private func startOutlineLoop() {
    stopOutlineLoop()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      self.updateOutline()
    }
    RunLoop.main.add(timer, forMode: .common)
    outlineTimer = timer
  }

  private func stopOutlineLoop() {
    outlineTimer?.invalidate()
    outlineTimer = nil
  }

  private func startSpotlightLoop() {
    if spotlightTimer != nil { return }
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      self.updateSpotlight()
    }
    RunLoop.main.add(timer, forMode: .common)
    spotlightTimer = timer
  }

  private func stopSpotlightLoop() {
    spotlightTimer?.invalidate()
    spotlightTimer = nil
  }

  private func updateOutline(force: Bool = false) {
    guard isEnabled else { return }
    reconcileScreensIfNeeded()

    let showOutline = ScreenUtils.isMultiDisplayNonMirrored()
    let displayID = showOutline ? ScreenUtils.cursorScreen()?.displayID : nil
    let currentState = OutlineState(
      showOutline: showOutline,
      activeDisplayID: displayID,
      windowCount: windowsByDisplayID.count
    )

    if !force, currentState == lastOutlineState {
      return
    }
    lastOutlineState = currentState

    guard showOutline else {
      for (_, window) in windowsByDisplayID {
        window.overlayView.setOutlineVisible(false)
      }
      return
    }

    for (id, window) in windowsByDisplayID {
      let isActive = (displayID != nil) && (id == displayID)
      if isActive {
        window.overlayView.updateOutline(strokeColor: .controlAccentColor, thickness: 4)
      }
      window.overlayView.setOutlineVisible(isActive)
    }
  }

  private func updateSpotlight() {
    guard isEnabled, spotlightActive else { return }
    reconcileScreensIfNeeded()

    guard let cursorScreen = ScreenUtils.cursorScreen(), let displayID = cursorScreen.displayID else { return }
    guard let window = windowsByDisplayID[displayID] else {
      NSLog("CursorOutline: spotlight missing overlay window for displayID=\(displayID)")
      return
    }

    let mouseScreenPoint = NSEvent.mouseLocation
    let windowPoint = window.convertPoint(fromScreen: mouseScreenPoint)
    let viewPoint = window.overlayView.convert(windowPoint, from: nil)

    for (id, otherWindow) in windowsByDisplayID {
      if id == displayID {
        otherWindow.overlayView.setSpotlightVisible(true, animated: false)
        otherWindow.overlayView.updateSpotlight(center: viewPoint, radius: 120)
      } else {
        otherWindow.overlayView.setSpotlightVisible(false, animated: false)
      }
    }
  }

  private func refreshScreens() {
    let screens = NSScreen.screens
    var alive: Set<CGDirectDisplayID> = []

    for screen in screens {
      guard let id = screen.displayID else { continue }
      alive.insert(id)

      if let existing = windowsByDisplayID[id] {
        existing.updateFrame(for: screen)
      } else {
        let window = OverlayPanel(screen: screen)
        windowsByDisplayID[id] = window
        NSLog("CursorOutline: created overlay window for displayID=\(id)")
      }
    }

    for (id, window) in windowsByDisplayID where !alive.contains(id) {
      window.orderOut(nil)
      windowsByDisplayID[id] = nil
      NSLog("CursorOutline: removed overlay window for displayID=\(id)")
    }

    NSLog("CursorOutline: refreshScreens complete. screens=\(screens.count) windows=\(windowsByDisplayID.count)")
  }

  private func reconcileScreensIfNeeded() {
    let liveIDs = Set(NSScreen.screens.compactMap(\.displayID))
    let knownIDs = Set(windowsByDisplayID.keys)
    guard liveIDs != knownIDs else { return }

    NSLog("CursorOutline: reconciling screens. liveIDs=\(formatIDs(liveIDs)) knownIDs=\(formatIDs(knownIDs))")
    refreshScreens()
  }

  private func formatIDs(_ ids: Set<CGDirectDisplayID>) -> String {
    ids.map { String($0) }.sorted().joined(separator: ",")
  }
}
