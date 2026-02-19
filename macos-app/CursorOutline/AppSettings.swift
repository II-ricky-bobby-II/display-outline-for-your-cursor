import AppKit
import Carbon
import Foundation

struct HotKeyConfig: Codable, Equatable {
  struct KeyOption: Equatable {
    let title: String
    let keyCode: UInt32
  }

  var keyCode: UInt32
  var modifiers: UInt32

  static let `default` = HotKeyConfig(
    keyCode: UInt32(kVK_ANSI_F),
    modifiers: UInt32(cmdKey | optionKey | controlKey)
  )

  static let fallback = HotKeyConfig(
    keyCode: UInt32(kVK_ANSI_G),
    modifiers: UInt32(cmdKey | optionKey | controlKey)
  )

  static let supportedKeys: [KeyOption] = [
    .init(title: "A", keyCode: UInt32(kVK_ANSI_A)),
    .init(title: "B", keyCode: UInt32(kVK_ANSI_B)),
    .init(title: "C", keyCode: UInt32(kVK_ANSI_C)),
    .init(title: "D", keyCode: UInt32(kVK_ANSI_D)),
    .init(title: "E", keyCode: UInt32(kVK_ANSI_E)),
    .init(title: "F", keyCode: UInt32(kVK_ANSI_F)),
    .init(title: "G", keyCode: UInt32(kVK_ANSI_G)),
    .init(title: "H", keyCode: UInt32(kVK_ANSI_H)),
    .init(title: "I", keyCode: UInt32(kVK_ANSI_I)),
    .init(title: "J", keyCode: UInt32(kVK_ANSI_J)),
    .init(title: "K", keyCode: UInt32(kVK_ANSI_K)),
    .init(title: "L", keyCode: UInt32(kVK_ANSI_L)),
    .init(title: "M", keyCode: UInt32(kVK_ANSI_M)),
    .init(title: "N", keyCode: UInt32(kVK_ANSI_N)),
    .init(title: "O", keyCode: UInt32(kVK_ANSI_O)),
    .init(title: "P", keyCode: UInt32(kVK_ANSI_P)),
    .init(title: "Q", keyCode: UInt32(kVK_ANSI_Q)),
    .init(title: "R", keyCode: UInt32(kVK_ANSI_R)),
    .init(title: "S", keyCode: UInt32(kVK_ANSI_S)),
    .init(title: "T", keyCode: UInt32(kVK_ANSI_T)),
    .init(title: "U", keyCode: UInt32(kVK_ANSI_U)),
    .init(title: "V", keyCode: UInt32(kVK_ANSI_V)),
    .init(title: "W", keyCode: UInt32(kVK_ANSI_W)),
    .init(title: "X", keyCode: UInt32(kVK_ANSI_X)),
    .init(title: "Y", keyCode: UInt32(kVK_ANSI_Y)),
    .init(title: "Z", keyCode: UInt32(kVK_ANSI_Z)),
  ]

  var displayString: String {
    let key = Self.supportedKeys.first(where: { $0.keyCode == keyCode })?.title ?? "KeyCode \(keyCode)"
    return Self.displayString(modifiers: modifiers, keyTitle: key)
  }

  static func displayString(modifiers: UInt32, keyTitle: String) -> String {
    var components: [String] = []
    if modifiers & UInt32(controlKey) != 0 { components.append("Control") }
    if modifiers & UInt32(optionKey) != 0 { components.append("Option") }
    if modifiers & UInt32(cmdKey) != 0 { components.append("Command") }
    if modifiers & UInt32(shiftKey) != 0 { components.append("Shift") }
    components.append(keyTitle)
    return components.joined(separator: "+")
  }
}

struct AppColor: Codable, Equatable {
  var red: Double
  var green: Double
  var blue: Double
  var alpha: Double

  static let `default` = AppColor(from: .controlAccentColor)

  init(from color: NSColor) {
    let rgb = color.usingColorSpace(.deviceRGB) ?? .controlAccentColor
    red = Double(rgb.redComponent)
    green = Double(rgb.greenComponent)
    blue = Double(rgb.blueComponent)
    alpha = Double(rgb.alphaComponent)
  }

  var nsColor: NSColor {
    NSColor(
      calibratedRed: red.clamped(to: 0...1),
      green: green.clamped(to: 0...1),
      blue: blue.clamped(to: 0...1),
      alpha: alpha.clamped(to: 0...1)
    )
  }
}

struct AppSettings: Codable, Equatable {
  var schemaVersion: Int
  var hotKey: HotKeyConfig
  var outlineThickness: Double
  var outlineColor: AppColor
  var spotlightRadius: Double
  var launchAtLogin: Bool

  static let currentSchemaVersion = 1

  static let defaults = AppSettings(
    schemaVersion: currentSchemaVersion,
    hotKey: .default,
    outlineThickness: 4,
    outlineColor: .default,
    spotlightRadius: 120,
    launchAtLogin: false
  )

  var sanitized: AppSettings {
    var copy = self
    copy.schemaVersion = Self.currentSchemaVersion
    if !HotKeyConfig.supportedKeys.contains(where: { $0.keyCode == copy.hotKey.keyCode }) {
      copy.hotKey.keyCode = HotKeyConfig.default.keyCode
    }
    if copy.hotKey.modifiers == 0 {
      copy.hotKey.modifiers = HotKeyConfig.default.modifiers
    }
    copy.outlineThickness = outlineThickness.clamped(to: 1...12)
    copy.spotlightRadius = spotlightRadius.clamped(to: 60...280)
    return copy
  }
}

final class AppSettingsStore {
  static let shared = AppSettingsStore()

  private let settingsKey = "appSettings.v1"
  private let defaults = UserDefaults.standard
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  func load() -> AppSettings {
    guard let payload = defaults.data(forKey: settingsKey) else {
      return .defaults
    }

    do {
      return try decoder.decode(AppSettings.self, from: payload).sanitized
    } catch {
      AppLogger.shared.log(.error, "Failed to decode settings; using defaults. error=\(error)")
      return .defaults
    }
  }

  func save(_ settings: AppSettings) {
    do {
      let payload = try encoder.encode(settings.sanitized)
      defaults.set(payload, forKey: settingsKey)
    } catch {
      AppLogger.shared.log(.error, "Failed to encode settings. error=\(error)")
    }
  }
}

private extension Double {
  func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
