import AppKit

final class OverlayController {
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
    return "Outline: On (multi display)"
  }

  private var windowsByDisplayID: [CGDirectDisplayID: OverlayPanel] = [:]

  private var screenObserver: Any?
  private var outlineTimer: Timer?
  private var spotlightTimer: Timer?

  private var spotlightActive = false

  func start() {
    refreshScreens()

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
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
      return
    }

    for (_, window) in windowsByDisplayID {
      window.orderFrontRegardless()
    }

    updateOutline()
  }

  private func startOutlineLoop() {
    stopOutlineLoop()
    let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
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

  private func updateOutline() {
    guard isEnabled else { return }

    let showOutline = ScreenUtils.isMultiDisplayNonMirrored()
    guard showOutline else {
      for (_, window) in windowsByDisplayID {
        window.overlayView.setOutlineVisible(false)
      }
      return
    }

    guard let cursorScreen = ScreenUtils.cursorScreen() else { return }
    let displayID = cursorScreen.displayID

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

    guard let cursorScreen = ScreenUtils.cursorScreen(), let displayID = cursorScreen.displayID else { return }
    guard let window = windowsByDisplayID[displayID] else { return }

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
      }
    }

    for (id, window) in windowsByDisplayID where !alive.contains(id) {
      window.orderOut(nil)
      windowsByDisplayID[id] = nil
    }
  }
}
