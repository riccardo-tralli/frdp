import Foundation

/// Represents a single RDP session and owns all per-session native resources.
///
/// Ownership chain:
/// - FrdpSession (this class)
///   - engine (FrdpRdpEngineAdapter)
///     - renderer + platform render view internals
///   - clipboardMonitor (FrdpClipboardMonitor)
///
/// Lifecycle:
/// - Created by FrdpConnectCoordinator during connect flow.
/// - Registered in FrdpSessionStore on successful connect.
/// - Removed by FrdpSessionStore.removeSession/removeAll.
/// - Deinitialization performs best-effort cleanup of engine/clipboard monitor.
///
/// Thread-safety:
/// - Identity/configuration fields are immutable.
/// - `state` is mutable and expected to be coordinated by callers.
/// - Clipboard monitor APIs are main-thread confined.
final class FrdpSession {
  let sessionId: String
  let host: String
  let port: Int
  let username: String
  let domain: String?
  let engine: FrdpRdpEngineAdapter
  var state: String
  let clipboardMonitor = FrdpClipboardMonitor()

  /// Called on the main thread when the remote host places new text on the
  /// clipboard.  Wired by FrdpPlugin to forward events to Dart.
  var onRemoteClipboard: ((String) -> Void)?

  init(host: String, port: Int, username: String, domain: String?) {
    sessionId = UUID().uuidString
    self.host = host
    self.port = port
    self.username = username
    self.domain = domain
    engine = FrdpRdpEngineAdapter()
    state = FrdpChannel.State.disconnected
  }

  deinit {
    // Ensure the transport is torn down if a session is released unexpectedly.
    engine.disconnect()

    // Clipboard monitor must be stopped on main queue.
    if Thread.isMainThread {
      clipboardMonitor.stop()
    } else {
      let monitor = clipboardMonitor
      DispatchQueue.main.async {
        monitor.stop()
      }
    }
  }
}
