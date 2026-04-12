import AppKit

// ---------------------------------------------------------------------------
// FrdpClipboardMonitor
//
// Polls NSPasteboard.general.changeCount at a fixed interval to detect
// whenever the user copies text on macOS.  When a change is detected the
// `onChange` callback is invoked on the main thread with the new text.
//
// Feedback-loop suppression: when the remote clipboard is received and
// written to NSPasteboard by the caller, `suppressNextChange(matching:)`
// should be called first.  If the next detected change matches that text the
// event is silently dropped, preventing the text from being re-sent to the
// remote host.
// ---------------------------------------------------------------------------
final class FrdpClipboardMonitor {
  // Default polling interval: 250 ms is imperceptible to the user and light
  // on CPU.  Reducing to 100 ms is safe if lower latency is needed.
  private static let pollInterval: TimeInterval = 0.25

  private var timer: Timer?
  private var lastChangeCount: Int
  private var suppressedText: String?
  private var onChange: ((String) -> Void)?

  init() {
    lastChangeCount = NSPasteboard.general.changeCount
  }

  // MARK: - Thread Safety

  // This type is main-thread confined: Timer, NSPasteboard access and mutable
  // state are expected to be accessed only on DispatchQueue.main.

  // MARK: - Start / Stop

  /// Begin monitoring.  `onChange` is called on the main thread whenever
  /// new text is found on the pasteboard.
  func start(onChange: @escaping (String) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard timer == nil else { return }
    self.onChange = onChange
    timer = Timer.scheduledTimer(
      withTimeInterval: Self.pollInterval,
      repeats: true
    ) { [weak self] _ in
      self?.checkForChanges()
    }
  }

  /// Stop monitoring and release the timer.
  func stop() {
    dispatchPrecondition(condition: .onQueue(.main))
    timer?.invalidate()
    timer = nil
    onChange = nil
    suppressedText = nil
  }

  // MARK: - Suppression

  /// Call this immediately before writing `text` to NSPasteboard so the
  /// resulting changeCount increment is not forwarded back to the remote.
  func suppressNextChange(matching text: String) {
    dispatchPrecondition(condition: .onQueue(.main))
    suppressedText = text
  }

  // MARK: - Internal

  private func checkForChanges() {
    dispatchPrecondition(condition: .onQueue(.main))

    let current = NSPasteboard.general.changeCount
    guard current != lastChangeCount else { return }
    lastChangeCount = current

    guard let text = NSPasteboard.general.string(forType: .string),
          !text.isEmpty else { return }

    // Drop the event if it matches the text we just wrote to the pasteboard
    // from the remote clipboard (avoid sending it right back).
    if text == suppressedText {
      suppressedText = nil
      return
    }
    suppressedText = nil
    onChange?(text)
  }
}
