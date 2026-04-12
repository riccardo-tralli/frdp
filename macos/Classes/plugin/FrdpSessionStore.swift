/// Thread-safe store for active RDP sessions.
/// 
/// This class manages a dictionary of FrdpSession objects that may be accessed
/// from multiple threads:
/// - Main thread: FrdpPlugin.handleGetConnectionState(), FrdpPlugin.handleDisconnect()
/// - Background thread: FrdpConnectCoordinator.connectQueue
///
/// All dictionary operations are synchronized using NSLock to prevent
/// EXC_BAD_ACCESS crashes from concurrent mutations.
final class FrdpSessionStore {
  private let lock = NSLock()
  private var sessions: [String: FrdpSession] = [:]

  /// Returns the collective connection state across all sessions.
  /// 
  /// Thread-safe. Queries are synchronized to ensure consistent snapshot.
  var globalState: String {
    lock.lock()
    defer { lock.unlock() }
    
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

  /// Registers a new session in the store.
  ///
  /// Thread-safe for concurrent access from main and background threads.
  /// - Parameter session: The session to add. Must have a unique sessionId.
  func addSession(_ session: FrdpSession) {
    lock.lock()
    defer { lock.unlock() }
    sessions[session.sessionId] = session
  }

  /// Retrieves a session by its identifier.
  ///
  /// Thread-safe for concurrent access. May return nil if session was
  /// removed concurrently.
  /// - Parameter id: The session identifier.
  /// - Returns: The session if found, nil otherwise.
  func getSession(id: String) -> FrdpSession? {
    lock.lock()
    defer { lock.unlock() }
    return sessions[id]
  }

  /// Removes a session and initiates its disconnection.
  ///
  /// Thread-safe for concurrent access. Calls disconnect() on the session's
  /// engine to ensure proper cleanup.
  /// - Parameter id: The session identifier to remove.
  func removeSession(id: String) {
    lock.lock()
    defer { lock.unlock() }
    
    if let session = sessions[id] {
      session.engine.disconnect()
    }
    sessions[id] = nil
  }

  /// Removes all sessions and disconnects them.
  ///
  /// Thread-safe for concurrent access. Iterates through all sessions,
  /// disconnecting each one, then clears the dictionary.
  func removeAll() {
    lock.lock()
    defer { lock.unlock() }
    
    sessions.values.forEach { $0.engine.disconnect() }
    sessions.removeAll()
  }
}
