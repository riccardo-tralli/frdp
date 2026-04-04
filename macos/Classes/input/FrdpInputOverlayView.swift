import Cocoa
import FlutterMacOS

final class FrdpInputOverlayView: NSView {
  private let engine: FrdpRdpEngineAdapter
  private var trackingAreaRef: NSTrackingArea?
  private var previousAcceptsMouseMovedEvents: Bool?

  private lazy var mouseInputHandler = FrdpMouseInputHandler(
    sendPointer: { [weak self] point, buttons in
      self?.forwardPointer(at: point, buttons: buttons)
    },
    sendScroll: { [weak self] deltaX, deltaY in
      self?.engine.sendScrollEvent(withDeltaX: deltaX, deltaY: deltaY)
    }
  )

  private lazy var keyboardInputHandler = FrdpKeyboardInputHandler(
    sendMacKey: { [weak self] keyCode, isDown in
      self?.engine.sendMacKeyEvent(withKeyCode: keyCode, isDown: isDown)
    }
  )

  private lazy var touchTapHandler = FrdpTouchTapHandler(
    currentLocalPointer: { [weak self] in
      self?.currentLocalPointer() ?? .zero
    },
    sendPointer: { [weak self] point, buttons in
      self?.forwardPointer(at: point, buttons: buttons)
    }
  )

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
    mouseInputHandler.handlePointerEvent(event, in: self)
  }

  override func mouseDragged(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func mouseUp(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func rightMouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    mouseInputHandler.handlePointerEvent(event, in: self)
  }

  override func rightMouseDragged(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func rightMouseUp(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func otherMouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    mouseInputHandler.handlePointerEvent(event, in: self)
  }

  override func otherMouseDragged(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func otherMouseUp(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func mouseMoved(with event: NSEvent) { mouseInputHandler.handlePointerEvent(event, in: self) }

  override func scrollWheel(with event: NSEvent) {
    mouseInputHandler.handleScrollEvent(event, in: self)
  }

  // MARK: - Keyboard events

  override func keyDown(with event: NSEvent) {
    keyboardInputHandler.keyDown(event)
  }

  override func keyUp(with event: NSEvent) {
    keyboardInputHandler.keyUp(event)
  }

  override func flagsChanged(with event: NSEvent) {
    guard keyboardInputHandler.flagsChanged(event) else {
      super.flagsChanged(with: event)
      return
    }
  }

  // MARK: - Touch events (trackpad tap-to-click)

  override func touchesBegan(with event: NSEvent) {
    super.touchesBegan(with: event)
    touchTapHandler.touchesBegan(event, in: self)
  }

  override func touchesMoved(with event: NSEvent) {
    super.touchesMoved(with: event)
    touchTapHandler.touchesMoved(event, in: self)
  }

  override func touchesEnded(with event: NSEvent) {
    super.touchesEnded(with: event)
    touchTapHandler.touchesEnded(event, in: self)
  }

  override func touchesCancelled(with event: NSEvent) {
    super.touchesCancelled(with: event)
    touchTapHandler.touchesCancelled(event, in: self)
  }

  // MARK: - Private helpers

  private func currentLocalPointer() -> NSPoint {
    guard let window else { return .zero }
    return convert(window.mouseLocationOutsideOfEventStream, from: nil)
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
