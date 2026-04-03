import Cocoa
import FlutterMacOS

final class FrdpInputOverlayView: NSView {
  private let engine: FrdpRdpEngineAdapter
  private var trackingAreaRef: NSTrackingArea?
  private var previousAcceptsMouseMovedEvents: Bool?
  private var tapCandidateActive = false
  private var tapCandidateMoved = false
  private var tapCandidateStartTime: TimeInterval = 0
  private var tapCandidateStartPoint: NSPoint = .zero
  private var tapCandidateButtons = 0

  init(engine: FrdpRdpEngineAdapter) {
    self.engine = engine
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    allowedTouchTypes = [.indirect]
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }
    let newArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .inVisibleRect, .mouseMoved, .enabledDuringMouseDrag],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(newArea)
    trackingAreaRef = newArea
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if let window, let previousAcceptsMouseMovedEvents {
      window.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
      self.previousAcceptsMouseMovedEvents = nil
    }
    super.viewWillMove(toWindow: newWindow)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else { return }
    if previousAcceptsMouseMovedEvents == nil {
      previousAcceptsMouseMovedEvents = window.acceptsMouseMovedEvents
    }
    window.acceptsMouseMovedEvents = true
  }

  // MARK: - Mouse events

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    forwardPointer(event)
  }

  override func mouseDragged(with event: NSEvent) { forwardPointer(event) }

  override func mouseUp(with event: NSEvent) { forwardPointer(event) }

  override func rightMouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    forwardPointer(event)
  }

  override func rightMouseDragged(with event: NSEvent) { forwardPointer(event) }

  override func rightMouseUp(with event: NSEvent) { forwardPointer(event) }

  override func otherMouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    forwardPointer(event)
  }

  override func otherMouseDragged(with event: NSEvent) { forwardPointer(event) }

  override func otherMouseUp(with event: NSEvent) { forwardPointer(event) }

  override func mouseMoved(with event: NSEvent) { forwardPointer(event) }

  override func scrollWheel(with event: NSEvent) {
    forwardPointer(event)
    engine.sendScrollEvent(withDeltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
  }

  // MARK: - Keyboard events

  override func keyDown(with event: NSEvent) {
    engine.sendMacKeyEvent(withKeyCode: Int(event.keyCode), isDown: true)
  }

  override func keyUp(with event: NSEvent) {
    engine.sendMacKeyEvent(withKeyCode: Int(event.keyCode), isDown: false)
  }

  override func flagsChanged(with event: NSEvent) {
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
      super.flagsChanged(with: event)
      return
    }

    engine.sendMacKeyEvent(withKeyCode: keyCode, isDown: isDown)
  }

  // MARK: - Touch events (trackpad tap-to-click)

  override func touchesBegan(with event: NSEvent) {
    super.touchesBegan(with: event)

    let touching = event.touches(matching: .touching, in: self)
    guard (NSEvent.pressedMouseButtons & 0x1) == 0 else {
      tapCandidateActive = false
      return
    }

    let tapButtons: Int
    switch touching.count {
    case 1:
      tapButtons = 0x1 // left click
    case 2:
      tapButtons = 0x2 // right click
    default:
      tapCandidateActive = false
      return
    }

    tapCandidateActive = true
    tapCandidateMoved = false
    tapCandidateStartTime = ProcessInfo.processInfo.systemUptime
    tapCandidateStartPoint = currentLocalPointer()
    tapCandidateButtons = tapButtons
  }

  override func touchesMoved(with event: NSEvent) {
    super.touchesMoved(with: event)
    guard tapCandidateActive else { return }

    // Cancel tap if finger count changes mid-gesture.
    let touching = event.touches(matching: .touching, in: self)
    if touching.count != 1 && touching.count != 2 {
      tapCandidateMoved = true
      return
    }

    let p = currentLocalPointer()
    let dx = p.x - tapCandidateStartPoint.x
    let dy = p.y - tapCandidateStartPoint.y
    if (dx * dx + dy * dy) > (14.0 * 14.0) {
      tapCandidateMoved = true
    }
  }

  override func touchesEnded(with event: NSEvent) {
    super.touchesEnded(with: event)
    guard tapCandidateActive else { return }
    defer { tapCandidateActive = false }

    let duration = ProcessInfo.processInfo.systemUptime - tapCandidateStartTime
    guard !tapCandidateMoved && duration <= 0.25 else { return }

    sendClick(at: currentLocalPointer(), buttons: tapCandidateButtons)
  }

  override func touchesCancelled(with event: NSEvent) {
    super.touchesCancelled(with: event)
    tapCandidateActive = false
  }

  // MARK: - Private helpers

  private func forwardPointer(_ event: NSEvent) {
    let localPoint = convert(event.locationInWindow, from: nil)
    let native = Int(NSEvent.pressedMouseButtons)
    var buttons = 0
    if (native & 0x1) != 0 { buttons |= 0x1 }
    if (native & 0x2) != 0 { buttons |= 0x2 }
    if (native & 0x4) != 0 { buttons |= 0x4 }
    forwardPointer(at: localPoint, buttons: buttons)
  }

  private func currentLocalPointer() -> NSPoint {
    guard let window else { return .zero }
    return convert(window.mouseLocationOutsideOfEventStream, from: nil)
  }

  private func sendClick(at localPoint: NSPoint, buttons: Int) {
    forwardPointer(at: localPoint, buttons: buttons)
    forwardPointer(at: localPoint, buttons: 0)
  }

  private func forwardPointer(at localPoint: NSPoint, buttons: Int) {
    let clampedX = min(max(localPoint.x, 0), bounds.width)
    let flippedY = bounds.height - localPoint.y
    let clampedY = min(max(flippedY, 0), bounds.height)

    engine.sendPointerEventWith(
      x: clampedX,
      y: clampedY,
      buttons: buttons,
      viewWidth: bounds.width,
      viewHeight: bounds.height
    )
  }
}
