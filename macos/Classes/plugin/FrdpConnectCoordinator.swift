import Foundation
import AppKit
import FlutterMacOS

/// Coordinates asynchronous RDP connection attempts.
///
/// Thread-safety:
/// - connectQueue performs blocking engine connect operations off the main thread.
/// - pendingConnectAttempts/pendingConnectCancels are protected by pendingLock,
///   because they are touched by timeout callbacks, cancel requests and connect
///   completion paths.
///
/// Session lifecycle:
/// - A connected session is added to FrdpSessionStore.
/// - When a session transitions to a terminal state without explicit
///   disconnect, a delayed cleanup pass removes stale sessions.
final class FrdpConnectCoordinator {
  private static let staleSessionCleanupDelayMs = 30_000

  private let connectQueue = DispatchQueue(label: "it.riccardotralli.frdp.connect", qos: .userInitiated)
  private let pendingLock = NSLock()
  private var pendingConnectAttempts: [String: FrdpConnectAttempt] = [:]
  private var pendingConnectCancels: [String: () -> Void] = [:]

  /// Called on the main thread when the remote host places new clipboard text.
  /// Arguments: (sessionId, text).  Set by FrdpPlugin on registration.
  var onRemoteClipboard: ((String, String) -> Void)?

  private static func startClipboardBridge(for session: FrdpSession) {
    session.clipboardMonitor.start { [weak session] text in
      session?.engine.sendLocalClipboardText(text)
    }

    if let existing = NSPasteboard.general.string(forType: .string), !existing.isEmpty {
      session.engine.sendLocalClipboardText(existing)
    }
  }

  private static func synchronizeLocalLockKeys(for session: FrdpSession) {
    // Use global keyboard lock states (not window-local modifier snapshot)
    // to avoid stale values right after app activation / focus changes.
    let capsLockOn = CGEventSource.keyState(.combinedSessionState, key: 57)
    session.engine.synchronizeLockState(withCapsLockEnabled: capsLockOn)

    // Some servers apply lock state only after the session reaches interactive
    // input stage; re-apply once shortly after connect.
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
      session.engine.synchronizeLockState(withCapsLockEnabled: capsLockOn)
    }
  }

  func connect(
    request: FrdpConnectRequest,
    sessionStore: FrdpSessionStore,
    result: @escaping FlutterResult
  ) {
    let session = FrdpSession(
      host: request.host,
      port: request.port,
      username: request.username,
      domain: request.domain
    )

    session.engine.connectionStateDidChange = { [weak session] connected in
      guard let session else { return }
      session.state = connected ? FrdpChannel.State.connected : FrdpChannel.State.disconnected
      if connected {
        if request.enableClipboard {
          FrdpConnectCoordinator.startClipboardBridge(for: session)
        }
      } else {
        session.clipboardMonitor.stop()
        Self.scheduleStaleSessionCleanup(session: session, sessionStore: sessionStore)
      }
    }

    session.state = FrdpChannel.State.connecting

    let attempt = FrdpConnectAttempt()
    let attemptId = attempt.attemptId

    setPendingAttempt(attempt, for: attemptId)

    attempt.scheduleTimeout(afterMs: request.timeoutMs) { [weak self, weak session] in
      self?.removePending(for: attemptId)
      session?.state = FrdpChannel.State.error
      result(
        FlutterError(
          code: "RDP_CONNECT_TIMEOUT",
          message: "RDP connect timed out after \(request.timeoutMs)ms.",
          details: nil
        )
      )
    }

    let cancelClosure: () -> Void = { [weak self, weak session] in
      guard attempt.cancel() else { return }

      self?.removePending(for: attemptId)
      session?.state = FrdpChannel.State.disconnected
      result(
        FlutterError(
          code: "RDP_CONNECT_CANCELED",
          message: "RDP connect canceled.",
          details: nil
        )
      )
    }

    setPendingCancel(cancelClosure, for: attemptId)

    // Build the optional custom performance config before jumping to the
    // background queue so we avoid any threading concerns with the struct.
    let customConfig: FrdpCustomProfileConfig? = request.hasCustomProfile
        ? FrdpConnectCoordinator.buildCustomConfig(from: request)
        : nil

    connectQueue.async {
      do {
        try session.engine.connect(
          withHost: request.host,
          port: request.port,
          username: request.username,
          password: request.password,
          domain: request.domain,
          ignoreCertificate: request.ignoreCertificate,
          enableClipboard: request.enableClipboard,
          disableClipboardPerformanceFallback: request.disableClipboardPerformanceFallback,
          performanceProfile: request.profile,
          renderingBackend: request.renderingBackend,
          customPerformanceConfig: customConfig
        )

        DispatchQueue.main.async { [weak self] in
          guard let self else { return }

          guard attempt.resolveOnce() else {
            session.engine.disconnect()
            return
          }

          self.removePending(for: attemptId)
          session.state = FrdpChannel.State.connected
          sessionStore.addSession(session)
          Self.synchronizeLocalLockKeys(for: session)

          // Wire remote clipboard: RDP → NSPasteboard + Flutter event.
          let remoteClipboardCallback = self.onRemoteClipboard
          let sessionId = session.sessionId
          if request.enableClipboard {
            session.engine.remoteClipboardDidChange = { [weak session] text in
              guard let session else { return }
              session.clipboardMonitor.suppressNextChange(matching: text)
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(text, forType: .string)
              remoteClipboardCallback?(sessionId, text)
            }
          } else {
            session.engine.remoteClipboardDidChange = nil
            session.clipboardMonitor.stop()
          }

          result([FrdpChannel.Arg.sessionId: session.sessionId, "state": session.state])
        }
      } catch {
        DispatchQueue.main.async { [weak self] in
          guard attempt.resolveOnce() else {
            return
          }

          self?.removePending(for: attemptId)
          session.state = FrdpChannel.State.error
          result(FlutterError(code: "RDP_CONNECT_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func cancelAllPending() {
    let cancelPending = drainPendingCancels()
    cancelPending.forEach { $0() }
  }

  // MARK: - Private helpers

  private static func scheduleStaleSessionCleanup(session: FrdpSession, sessionStore: FrdpSessionStore) {
    let sessionId = session.sessionId
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(staleSessionCleanupDelayMs)) {
      _ = sessionStore.removeSessionIfTerminal(id: sessionId, matching: session)
    }
  }

  /// Stores a connect attempt in the pending map.
  private func setPendingAttempt(_ attempt: FrdpConnectAttempt, for attemptId: String) {
    pendingLock.lock()
    defer { pendingLock.unlock() }
    pendingConnectAttempts[attemptId] = attempt
  }

  /// Stores the cancellation closure for an attempt.
  private func setPendingCancel(_ cancel: (() -> Void)?, for attemptId: String) {
    guard let cancel else { return }
    pendingLock.lock()
    defer { pendingLock.unlock() }
    pendingConnectCancels[attemptId] = cancel
  }

  /// Removes both pending maps for a given attempt id atomically.
  private func removePending(for attemptId: String) {
    pendingLock.lock()
    defer { pendingLock.unlock() }
    pendingConnectAttempts.removeValue(forKey: attemptId)
    pendingConnectCancels.removeValue(forKey: attemptId)
  }

  /// Drains cancel closures atomically so callers can execute them without
  /// holding the lock.
  private func drainPendingCancels() -> [() -> Void] {
    pendingLock.lock()
    defer { pendingLock.unlock() }
    let cancelPending = Array(pendingConnectCancels.values)
    pendingConnectCancels.removeAll()
    return cancelPending
  }

  private static func buildCustomConfig(from request: FrdpConnectRequest) -> FrdpCustomProfileConfig {
    let config = FrdpCustomProfileConfig()
    config.desktopWidth            = UInt(request.customDesktopWidth  ?? 1280)
    config.desktopHeight           = UInt(request.customDesktopHeight ?? 720)
    config.connectionType          = UInt(request.customConnectionTypeValue ?? 2)
    config.colorDepth              = UInt(request.customColorDepth    ?? 32)
    config.disableWallpaper        = request.customDisableWallpaper        ?? true
    config.disableFullWindowDrag   = request.customDisableFullWindowDrag   ?? true
    config.disableMenuAnimations   = request.customDisableMenuAnimations   ?? true
    config.disableThemes           = request.customDisableThemes           ?? true
    config.allowDesktopComposition = request.customAllowDesktopComposition ?? false
    config.allowFontSmoothing      = request.customAllowFontSmoothing      ?? false
    config.gfxSurfaceCommandsEnabled = request.customGfxSurfaceCommandsEnabled ?? false
    config.gfxProgressive            = request.customGfxProgressive            ?? false
    config.gfxProgressiveV2          = request.customGfxProgressiveV2          ?? false
    config.gfxPlanar                 = request.customGfxPlanar                 ?? false
    config.gfxH264                   = request.customGfxH264                   ?? false
    config.gfxAvc444                 = request.customGfxAvc444                 ?? false
    config.gfxAvc444V2               = request.customGfxAvc444V2               ?? false
    return config
  }
}

