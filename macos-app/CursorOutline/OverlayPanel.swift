import AppKit

final class OverlayPanel: NSPanel {
  let overlayView: OverlayView

  init(screen: NSScreen) {
    overlayView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
    overlayView.autoresizingMask = [.width, .height]

    super.init(
      contentRect: screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: screen
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    level = .statusBar
    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .fullScreenAuxiliary,
      .ignoresCycle,
    ]

    titleVisibility = .hidden
    titlebarAppearsTransparent = true

    contentView = overlayView
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func updateFrame(for screen: NSScreen) {
    setFrame(screen.frame, display: false)
    overlayView.frame = NSRect(origin: .zero, size: frame.size)
    overlayView.needsLayout = true
  }
}
