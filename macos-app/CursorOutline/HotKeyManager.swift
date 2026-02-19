import Carbon
import Foundation

enum HotKeyError: Error {
  case registerFailed(OSStatus)
  case installHandlerFailed(OSStatus)
}

final class HotKeyManager {
  var onPressed: (() -> Void)?
  var onReleased: (() -> Void)?

  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?

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

  func register(keyCode: UInt32, modifiers: UInt32) throws {
    unregister()

    var eventTypes = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]

    let userData = Unmanaged.passUnretained(self).toOpaque()
    let statusInstall = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventHandler,
      eventTypes.count,
      &eventTypes,
      userData,
      &handlerRef
    )
    if statusInstall != noErr {
      throw HotKeyError.installHandlerFailed(statusInstall)
    }
    NSLog("CursorOutline: installed hotkey event handler")

    let statusRegister = RegisterEventHotKey(
      keyCode,
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    if statusRegister != noErr {
      unregister()
      throw HotKeyError.registerFailed(statusRegister)
    }
    NSLog("CursorOutline: registered Carbon hotkey keyCode=\(keyCode) modifiers=\(modifiers)")
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
    if status != noErr {
      return status
    }

    guard hotKeyID.signature == manager.hotKeyID.signature, hotKeyID.id == manager.hotKeyID.id else {
      return noErr
    }

    let kind = GetEventKind(event)
    if kind == UInt32(kEventHotKeyPressed) {
      manager.onPressed?()
    } else if kind == UInt32(kEventHotKeyReleased) {
      manager.onReleased?()
    }

    return noErr
  }
}
