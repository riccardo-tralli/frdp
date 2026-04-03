final class FrdpSession {
  let sessionId: String
  let host: String
  let port: Int
  let username: String
  let password: String
  let domain: String?
  let engine: FrdpRdpEngineAdapter
  var state: String

  init(host: String, port: Int, username: String, password: String, domain: String?) {
    sessionId = UUID().uuidString
    self.host = host
    self.port = port
    self.username = username
    self.password = password
    self.domain = domain
    engine = FrdpRdpEngineAdapter()
    state = FrdpChannel.State.disconnected
  }
}
