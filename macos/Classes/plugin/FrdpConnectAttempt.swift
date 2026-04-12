import Foundation

/// Tracks a single asynchronous connect attempt and guarantees one terminal
/// outcome (resolved/canceled/timedOut).
///
/// Thread-safety:
/// - Public APIs may be called from different queues (main + connect queue).
/// - Internal state transitions are serialized by `lock`.
final class FrdpConnectAttempt {
  enum State {
    case pending
    case resolved
    case canceled
    case timedOut
  }

  let attemptId = UUID().uuidString

  private var state: State = .pending
  private var timeoutWorkItem: DispatchWorkItem?
  private let lock = NSLock()

  func resolveOnce() -> Bool {
    transition(to: .resolved)
  }

  func cancel() -> Bool {
    transition(to: .canceled)
  }

  func scheduleTimeout(afterMs timeoutMs: Int, onTimeout: @escaping () -> Void) {
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      if self.transition(to: .timedOut) {
        onTimeout()
      }
    }

    lock.lock()
    timeoutWorkItem = work
    lock.unlock()

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: work)
  }

  private func transition(to nextState: State) -> Bool {
    lock.lock()
    guard state == .pending else {
      lock.unlock()
      return false
    }

    state = nextState
    let pendingTimeout = timeoutWorkItem
    timeoutWorkItem = nil
    lock.unlock()

    pendingTimeout?.cancel()
    return true
  }
}
