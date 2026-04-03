final class FrdpSessionStore {
  private var sessions: [String: FrdpSession] = [:]

  var globalState: String {
    if sessions.values.contains(where: { $0.state == FrdpChannel.State.error }) {
      return FrdpChannel.State.error
    }
    if sessions.values.contains(where: { $0.state == FrdpChannel.State.connected }) {
      return FrdpChannel.State.connected
    }
    if sessions.values.contains(where: { $0.state == FrdpChannel.State.connecting }) {
      return FrdpChannel.State.connecting
    }
    return FrdpChannel.State.disconnected
  }

  func createSession(
    host: String,
    port: Int,
    username: String,
    password: String,
    domain: String?
  ) -> FrdpSession {
    let session = FrdpSession(
      host: host,
      port: port,
      username: username,
      password: password,
      domain: domain
    )
    sessions[session.sessionId] = session
    return session
  }

  func getSession(id: String) -> FrdpSession? {
    sessions[id]
  }

  func removeSession(id: String) {
    sessions[id]?.engine.disconnect()
    sessions[id] = nil
  }

  func removeAll() {
    sessions.values.forEach { $0.engine.disconnect() }
    sessions.removeAll()
  }
}
