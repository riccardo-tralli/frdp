import "channel/frdp_platform_interface.dart";
import "models/frdp_connection_config.dart";
import "models/frdp_connection_state.dart";
import "models/frdp_session.dart";

/// The main class for interacting with the Frdp plugin.
class Frdp {
  /// Constructs a [Frdp] instance.
  const Frdp();

  /// Returns a [String] containing the current platform version.
  Future<String?> getPlatformVersion() {
    return FrdpPlatform.instance.getPlatformVersion();
  }

  /// Connects to a remote desktop using the provided [config].
  ///
  /// The [config] parameter should include all necessary information for establishing the connection, such as host, port, username, password, and any additional options.
  /// Returns a [FrdpSession] representing the established session.
  /// Throws an error if the connection fails.
  Future<FrdpSession> connect(FrdpConnectionConfig config) async {
    final session = await FrdpPlatform.instance.connect(config.toMap());
    return FrdpSession.fromMap(session);
  }

  /// Disconnects from the remote desktop session with the optional [sessionId].
  ///
  /// If [sessionId] is not provided, the current session will be disconnected.
  /// Throws an error if the disconnection fails or if there is no active session to disconnect from.
  Future<void> disconnect({String? sessionId}) {
    return FrdpPlatform.instance.disconnect(sessionId: sessionId);
  }

  /// Retrieves the current connection state of the remote desktop session with the optional [sessionId].
  ///
  /// Returns a [FrdpConnectionState] indicating the current state of the connection, such as connected, disconnected, connecting, or error.
  /// Throws an error if the state retrieval fails or if there is no active session with the specified [sessionId].
  Future<FrdpConnectionState> getConnectionState({String? sessionId}) async {
    final state = await FrdpPlatform.instance.getConnectionState(
      sessionId: sessionId,
    );
    return parseFrdpConnectionState(state);
  }

  /// Checks if the remote desktop session with the optional [sessionId] is currently connected.
  ///
  /// Returns `true` if the session is connected, `false` otherwise.
  /// Throws an error if the connection state retrieval fails or if there is no active session with the specified [sessionId].
  Future<bool> isConnected({String? sessionId}) async {
    final state = await getConnectionState(sessionId: sessionId);
    return state == FrdpConnectionState.connected;
  }

  /// Sends a pointer event to the remote desktop session with the specified [sessionId].
  ///
  /// The [x] and [y] parameters represent the coordinates of the pointer event, while [buttons] indicates which mouse buttons are pressed.
  /// The [buttons] parameter is a bitmask where:
  /// - 1: Left button
  /// - 2: Right button
  /// - 4: Middle button
  /// - 8: Button 4 (typically the "back" button on a mouse)
  /// - 16: Button 5 (typically the "forward" button on a mouse)
  Future<void> sendPointerEvent({
    required String sessionId,
    required double x,
    required double y,
    required int buttons,
  }) {
    return FrdpPlatform.instance.sendPointerEvent(
      sessionId: sessionId,
      x: x,
      y: y,
      buttons: buttons,
    );
  }

  /// Sends a key event to the remote desktop session with the specified [sessionId].
  ///
  /// The [keyCode] parameter represents the code of the key being pressed or released, while [isDown] indicates whether the key is being pressed (`true`) or released (`false`).
  Future<void> sendKeyEvent({
    required String sessionId,
    required int keyCode,
    required bool isDown,
  }) {
    return FrdpPlatform.instance.sendKeyEvent(
      sessionId: sessionId,
      keyCode: keyCode,
      isDown: isDown,
    );
  }
}
