import AppKit
import CoreGraphics

enum ScreenUtils {
  static func cursorScreen() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
      return screen
    }
    return NSScreen.main
  }

  static func isMultiDisplayNonMirrored() -> Bool {
    var primaryDisplays: [CGDirectDisplayID] = []
    for screen in NSScreen.screens {
      guard let id = screen.displayID else { continue }
      if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay {
        continue
      }
      primaryDisplays.append(id)
    }

    if !primaryDisplays.isEmpty {
      return primaryDisplays.count > 1
    }

    let uniqueFrames = Set(NSScreen.screens.map { NSStringFromRect($0.frame) })
    return uniqueFrames.count > 1
  }
}

extension NSScreen {
  var displayID: CGDirectDisplayID? {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    guard let screenNumber = deviceDescription[key] as? NSNumber else { return nil }
    return CGDirectDisplayID(truncating: screenNumber)
  }
}
