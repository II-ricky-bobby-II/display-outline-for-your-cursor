import Carbon
import Foundation

enum HotKeyRegistrationError: LocalizedError {
  case installHandlerFailed(OSStatus)
  case registrationFailed(OSStatus)

  var statusCode: OSStatus {
    switch self {
    case let .installHandlerFailed(code):
      return code
    case let .registrationFailed(code):
      return code
    }
  }

  var isConflict: Bool {
    statusCode == eventHotKeyExistsErr
  }

  var errorDescription: String? {
    switch self {
    case let .installHandlerFailed(code):
      return "Failed to install hotkey event handler (OSStatus \(code))."
    case let .registrationFailed(code):
      if code == eventHotKeyExistsErr {
        return "The selected hotkey is already in use by another app or macOS."
      }
      return "Failed to register global hotkey (OSStatus \(code))."
    }
  }
}

final class HotKeyManager {
  var onPressed: (() -> Void)?
  var onReleased: (() -> Void)?

  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?
  private(set) var activeHotKey: HotKeyConfig?

  private let hotKeyID: EventHotKeyID = {
    let signature = HotKeyManager.fourCharCode("COut")
    return EventHotKeyID(signature: signature, id: 1)
  }()

  private static func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for byte in string.utf8.prefix(4) {
      result = (result << 8) + FourCharCode(byte)
    }
    return result
  }

  func register(hotKey: HotKeyConfig) throws {
    unregister()

    var eventTypes = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]

    let userData = Unmanaged.passUnretained(self).toOpaque()
    let installStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventHandler,
      eventTypes.count,
      &eventTypes,
      userData,
      &handlerRef
    )

    guard installStatus == noErr else {
      throw HotKeyRegistrationError.installHandlerFailed(installStatus)
    }

    let registerStatus = RegisterEventHotKey(
      hotKey.keyCode,
      hotKey.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard registerStatus == noErr else {
      unregister()
      throw HotKeyRegistrationError.registrationFailed(registerStatus)
    }

    activeHotKey = hotKey
    AppLogger.shared.log(.info, "Registered global hotkey: \(hotKey.displayString)")
  }

  func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }

    if let handlerRef {
      RemoveEventHandler(handlerRef)
      self.handlerRef = nil
    }

    activeHotKey = nil
  }

  deinit {
    unregister()
  }

  private static let eventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    guard status == noErr else { return status }
    guard hotKeyID.signature == manager.hotKeyID.signature, hotKeyID.id == manager.hotKeyID.id else {
      return noErr
    }

    switch GetEventKind(event) {
    case UInt32(kEventHotKeyPressed):
      manager.onPressed?()
    case UInt32(kEventHotKeyReleased):
      manager.onReleased?()
    default:
      break
    }

    return noErr
  }
}
