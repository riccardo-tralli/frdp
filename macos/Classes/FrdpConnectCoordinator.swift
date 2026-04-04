import Foundation
import FlutterMacOS

final class FrdpConnectCoordinator {
  private let connectQueue = DispatchQueue(label: "it.riccardotralli.frdp.connect", qos: .userInitiated)
  private var pendingConnectAttempts: [String: FrdpConnectAttempt] = [:]
  private var pendingConnectCancels: [String: () -> Void] = [:]

  func connect(
    host: String,
    port: Int,
    username: String,
    password: String,
    domain: String?,
    profile: String,
    ignoreCertificate: Bool,
    timeoutMs: Int,
    sessionStore: FrdpSessionStore,
    result: @escaping FlutterResult
  ) {
    let session = FrdpSession(
      host: host,
      port: port,
      username: username,
      domain: domain
    )

    session.engine.connectionStateDidChange = { [weak session] connected in
      guard let session else { return }
      session.state = connected ? FrdpChannel.State.connected : FrdpChannel.State.disconnected
    }

    session.state = FrdpChannel.State.connecting

    let attempt = FrdpConnectAttempt()
    let attemptId = attempt.attemptId

    pendingConnectAttempts[attemptId] = attempt

    attempt.scheduleTimeout(afterMs: timeoutMs) { [weak self, weak session] in
      self?.pendingConnectAttempts.removeValue(forKey: attemptId)
      self?.pendingConnectCancels.removeValue(forKey: attemptId)
      session?.state = FrdpChannel.State.error
      result(
        FlutterError(
          code: "RDP_CONNECT_TIMEOUT",
          message: "RDP connect timed out after \(timeoutMs)ms.",
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

    connectQueue.async {
      do {
        try session.engine.connect(
          withHost: host,
          port: port,
          username: username,
          password: password,
          domain: domain,
          ignoreCertificate: ignoreCertificate,
          performanceProfile: profile
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
}
