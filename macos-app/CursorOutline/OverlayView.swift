import AppKit

final class OverlayView: NSView {
  private let outlineLayer = CAShapeLayer()
  private let spotlightLayer = CAShapeLayer()

  private var outlineThickness: CGFloat = 4
  private var lastSpotlightCenter: NSPoint?
  private var lastSpotlightRadius: CGFloat?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    wantsLayer = true
    layer?.masksToBounds = false

    outlineLayer.fillColor = nil
    outlineLayer.strokeColor = NSColor.controlAccentColor.cgColor
    outlineLayer.lineJoin = .round
    outlineLayer.lineCap = .round
    outlineLayer.isHidden = true
    layer?.addSublayer(outlineLayer)

    spotlightLayer.fillRule = .evenOdd
    spotlightLayer.fillColor = NSColor.black.withAlphaComponent(0.34).cgColor
    spotlightLayer.opacity = 0
    spotlightLayer.isHidden = true
    layer?.addSublayer(spotlightLayer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()

    outlineLayer.frame = bounds
    spotlightLayer.frame = bounds

    updateOutlinePath()

    if let c = lastSpotlightCenter, let r = lastSpotlightRadius {
      updateSpotlight(center: c, radius: r)
    }
  }

  func setOutlineVisible(_ visible: Bool) {
    outlineLayer.isHidden = !visible
  }

  func updateOutline(strokeColor: NSColor, thickness: CGFloat) {
    outlineThickness = thickness
    outlineLayer.lineWidth = thickness

    let base = strokeColor.usingColorSpace(.deviceRGB) ?? strokeColor
    outlineLayer.strokeColor = base.withAlphaComponent(0.95).cgColor
    outlineLayer.shadowColor = base.withAlphaComponent(0.55).cgColor
    outlineLayer.shadowOpacity = 1.0
    outlineLayer.shadowRadius = 10
    outlineLayer.shadowOffset = .zero

    updateOutlinePath()
  }

  private func updateOutlinePath() {
    let inset = outlineThickness / 2.0
    let rect = bounds.insetBy(dx: inset, dy: inset)
    outlineLayer.path = CGPath(rect: rect, transform: nil)
  }

  func setSpotlightVisible(_ visible: Bool, animated: Bool) {
    let targetOpacity: Float = visible ? 1.0 : 0.0
    if !animated {
      spotlightLayer.isHidden = !visible
      spotlightLayer.opacity = targetOpacity
      return
    }

    spotlightLayer.isHidden = false

    CATransaction.begin()
    CATransaction.setAnimationDuration(visible ? 0.08 : 0.18)
    CATransaction.setCompletionBlock { [weak self] in
      guard let self else { return }
      if !visible {
        self.spotlightLayer.isHidden = true
        self.lastSpotlightCenter = nil
        self.lastSpotlightRadius = nil
      }
    }

    spotlightLayer.opacity = targetOpacity
    CATransaction.commit()
  }

  func updateSpotlight(center: NSPoint, radius: CGFloat) {
    lastSpotlightCenter = center
    lastSpotlightRadius = radius

    let holeRect = NSRect(
      x: center.x - radius,
      y: center.y - radius,
      width: radius * 2,
      height: radius * 2
    )

    let path = CGMutablePath()
    path.addRect(bounds)
    path.addEllipse(in: holeRect)

    spotlightLayer.path = path
  }
}
