import Cocoa

/// Translates AppKit keyboard events into engine callback payloads.
///
/// Thread-safety:
/// - Main-thread confined (NSEvent access).
final class FrdpKeyboardInputHandler {
  private let sendMacKey: (Int, Bool) -> Void

  init(sendMacKey: @escaping (Int, Bool) -> Void) {
    self.sendMacKey = sendMacKey
  }

  func keyDown(_ event: NSEvent) {
    sendMacKey(Int(event.keyCode), true)
  }

  func keyUp(_ event: NSEvent) {
    sendMacKey(Int(event.keyCode), false)
  }

  /// Returns true if the event was handled, false if caller should forward to super.
  func flagsChanged(_ event: NSEvent) -> Bool {
    let keyCode = Int(event.keyCode)
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

    let isDown: Bool
    switch keyCode {
    case 54, 55: isDown = flags.contains(.command)
    case 56, 60: isDown = flags.contains(.shift)
    case 58, 61: isDown = flags.contains(.option)
    case 59, 62: isDown = flags.contains(.control)
    case 57:     isDown = flags.contains(.capsLock)
    default:
      return false
    }

    sendMacKey(keyCode, isDown)
    return true
  }
}
