import Foundation
import FlutterMacOS

final class FrdpConnectCoordinator {
  private let connectQueue = DispatchQueue(label: "it.riccardotralli.frdp.connect", qos: .userInitiated)
  private var pendingConnectAttempts: [String: FrdpConnectAttempt] = [:]
  private var pendingConnectCancels: [String: () -> Void] = [:]

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
    return config
  }
}

