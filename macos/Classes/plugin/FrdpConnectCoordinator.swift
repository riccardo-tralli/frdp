import Foundation
import AppKit
import FlutterMacOS

final class FrdpConnectCoordinator {
  private let connectQueue = DispatchQueue(label: "it.riccardotralli.frdp.connect", qos: .userInitiated)
  private var pendingConnectAttempts: [String: FrdpConnectAttempt] = [:]
  private var pendingConnectCancels: [String: () -> Void] = [:]

  /// Called on the main thread when the remote host places new clipboard text.
  /// Arguments: (sessionId, text).  Set by FrdpPlugin on registration.
  var onRemoteClipboard: ((String, String) -> Void)?

  private static func startClipboardBridgeIfNeeded(for session: FrdpSession) {
    session.clipboardMonitor.start { [weak session] text in
      session?.engine.sendLocalClipboardText(text)
    }

    // Prime the remote clipboard with current local text right after connect,
    // so paste on the remote host works even before the next copy action.
    if let existing = NSPasteboard.general.string(forType: .string), !existing.isEmpty {
      session.engine.sendLocalClipboardText(existing)
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
        FrdpConnectCoordinator.startClipboardBridgeIfNeeded(for: session)
      } else {
        session.clipboardMonitor.stop()
      }
    }

    session.state = FrdpChannel.State.connecting

    let attempt = FrdpConnectAttempt()
    let attemptId = attempt.attemptId

    pendingConnectAttempts[attemptId] = attempt

    attempt.scheduleTimeout(afterMs: request.timeoutMs) { [weak self, weak session] in
      self?.pendingConnectAttempts.removeValue(forKey: attemptId)
      self?.pendingConnectCancels.removeValue(forKey: attemptId)
      session?.state = FrdpChannel.State.error
      result(
        FlutterError(
          code: "RDP_CONNECT_TIMEOUT",
          message: "RDP connect timed out after \(request.timeoutMs)ms.",
          details: nil
        )
      )
    }

    pendingConnectCancels[attemptId] = { [weak self, weak session] in
      guard attempt.cancel() else { return }

      self?.pendingConnectAttempts.removeValue(forKey: attemptId)
      self?.pendingConnectCancels.removeValue(forKey: attemptId)
      session?.state = FrdpChannel.State.disconnected
      result(
        FlutterError(
          code: "RDP_CONNECT_CANCELED",
          message: "RDP connect canceled.",
          details: nil
        )
      )
    }

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

          self.pendingConnectAttempts.removeValue(forKey: attemptId)
          self.pendingConnectCancels.removeValue(forKey: attemptId)
          session.state = FrdpChannel.State.connected
          sessionStore.addSession(session)

          // Wire remote clipboard: RDP → NSPasteboard + Flutter event.
          let remoteClipboardCallback = self.onRemoteClipboard
          let sessionId = session.sessionId
          session.engine.remoteClipboardDidChange = { [weak session] text in
            guard let session else { return }
            session.clipboardMonitor.suppressNextChange(matching: text)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            remoteClipboardCallback?(sessionId, text)
          }

          result([FrdpChannel.Arg.sessionId: session.sessionId, "state": session.state])
        }
      } catch {
        DispatchQueue.main.async { [weak self] in
          guard attempt.resolveOnce() else {
            return
          }

          self?.pendingConnectAttempts.removeValue(forKey: attemptId)
          self?.pendingConnectCancels.removeValue(forKey: attemptId)
          session.state = FrdpChannel.State.error
          result(FlutterError(code: "RDP_CONNECT_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func cancelAllPending() {
    let cancelPending = Array(pendingConnectCancels.values)
    pendingConnectCancels.removeAll()
    cancelPending.forEach { $0() }
  }

  // MARK: - Private helpers

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

