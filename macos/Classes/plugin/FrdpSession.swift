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
}
