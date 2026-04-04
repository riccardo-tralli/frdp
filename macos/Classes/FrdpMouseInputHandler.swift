import Cocoa

final class FrdpMouseInputHandler {
  private let sendPointer: (NSPoint, Int) -> Void
  private let sendScroll: (Double, Double) -> Void

  init(sendPointer: @escaping (NSPoint, Int) -> Void,
       sendScroll: @escaping (Double, Double) -> Void) {
    self.sendPointer = sendPointer
    self.sendScroll = sendScroll
  }

  func handlePointerEvent(_ event: NSEvent, in view: NSView) {
    let localPoint = view.convert(event.locationInWindow, from: nil)
    sendPointer(localPoint, Self.buttonsMask(from: NSEvent.pressedMouseButtons))
  }

  func handleScrollEvent(_ event: NSEvent, in view: NSView) {
    handlePointerEvent(event, in: view)
    sendScroll(event.scrollingDeltaX, event.scrollingDeltaY)
  }

  private static func buttonsMask(from nativeMask: Int) -> Int {
    var buttons = 0
    if (nativeMask & 0x1) != 0 { buttons |= 0x1 }
    if (nativeMask & 0x2) != 0 { buttons |= 0x2 }
    if (nativeMask & 0x4) != 0 { buttons |= 0x4 }
    return buttons
  }
}
