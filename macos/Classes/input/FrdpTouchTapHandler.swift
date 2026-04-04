import Cocoa

final class FrdpTouchTapHandler {
  private let currentLocalPointer: () -> NSPoint
  private let sendPointer: (NSPoint, Int) -> Void

  private var tapCandidateActive = false
  private var tapCandidateMoved = false
  private var tapCandidateStartTime: TimeInterval = 0
  private var tapCandidateStartPoint: NSPoint = .zero
  private var tapCandidateButtons = 0

  init(currentLocalPointer: @escaping () -> NSPoint,
       sendPointer: @escaping (NSPoint, Int) -> Void) {
    self.currentLocalPointer = currentLocalPointer
    self.sendPointer = sendPointer
  }

  func touchesBegan(_ event: NSEvent, in view: NSView) {
    let touching = event.touches(matching: .touching, in: view)
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

  func touchesMoved(_ event: NSEvent, in view: NSView) {
    guard tapCandidateActive else { return }

    // Cancel tap if finger count changes mid-gesture.
    let touching = event.touches(matching: .touching, in: view)
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

  func touchesEnded(_ event: NSEvent, in view: NSView) {
    guard tapCandidateActive else { return }
    defer { tapCandidateActive = false }

    let duration = ProcessInfo.processInfo.systemUptime - tapCandidateStartTime
    guard !tapCandidateMoved && duration <= 0.25 else { return }

    let point = currentLocalPointer()
    sendPointer(point, tapCandidateButtons)
    sendPointer(point, 0)
  }

  func touchesCancelled(_ event: NSEvent, in view: NSView) {
    tapCandidateActive = false
  }
}
