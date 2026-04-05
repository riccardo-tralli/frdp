import "channel/frdp_platform_interface.dart";
import "models/frdp_connection_config.dart";
import "models/frdp_connection_state.dart";
import "models/frdp_session.dart";

/// Flutter Remote Desktop Protocol (Frdp).
///
/// Frdp allows you to connect to and interact with remote desktop sessions from
/// your Flutter application. It provides methods for establishing connections,
/// sending input events, and managing session states.
class Frdp {
  /// Flutter Remote Desktop Protocol instance.
  const Frdp();

  /// Returns a [String] containing the current platform version.
  Future<String?> getPlatformVersion() {
    return FrdpPlatform.instance.getPlatformVersion();
  }

  /// Connects to a remote desktop using the provided [config].
  ///
  /// The [config] parameter should include all necessary information for
  /// establishing the connection, such as host, port, username, password, and
  /// any additional options.
  ///
  /// Returns a [FrdpSession] representing the established session.
  ///
  /// Throws an error if the connection fails.
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  Future<FrdpSession> connect(FrdpConnectionConfig config) async {
    final session = await FrdpPlatform.instance.connect(config.toMap());
    return FrdpSession.fromMap(session);
  }

  /// Disconnects from the remote desktop session with the optional [sessionId].
  ///
  /// If [sessionId] is not provided, the current session will be disconnected.
  ///
  /// Throws an error if the disconnection fails or if there is no active
  /// session to disconnect from.
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// // ... interact with the session ...
  /// await frdp.disconnect(session.id);
  /// ```
  Future<void> disconnect([String? sessionId]) {
    return FrdpPlatform.instance.disconnect(sessionId);
  }

  /// Retrieves the current connection state of the remote desktop session with
  /// the optional [sessionId].
  ///
  /// Returns a [FrdpConnectionState] indicating the current state of the
  /// connection, such as connected, disconnected, connecting, or error.
  ///
  /// Throws an error if the state retrieval fails or if there is no active
  /// session with the specified [sessionId].
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// final connectionState = await frdp.getConnectionState(session.id);
  /// print("Connection state: $connectionState");
  /// ```
  Future<FrdpConnectionState> getConnectionState([String? sessionId]) async {
    final state = await FrdpPlatform.instance.getConnectionState(sessionId);
    return parseFrdpConnectionState(state);
  }

  /// Checks if the remote desktop session with the optional [sessionId] is
  /// currently connected.
  ///
  /// Returns `true` if the session is connected, `false` otherwise.
  /// Throws an error if the connection state retrieval fails or if there is no
  /// active session with the specified [sessionId].
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// final isConnected = await frdp.isConnected(session.id);
  /// print("Is session connected? $isConnected");
  /// ```
  Future<bool> isConnected([String? sessionId]) async {
    final state = await getConnectionState(sessionId);
    return state == FrdpConnectionState.connected;
  }

  /// Sends a pointer event to the remote desktop session with the specified [sessionId].
  ///
  /// The [x] and [y] parameters represent the coordinates of the pointer event,
  /// while [buttons] indicates which mouse buttons are pressed.
  ///
  /// The [buttons] parameter is a bitmask where:
  /// - 1: Left button
  /// - 2: Right button
  /// - 4: Middle button
  /// - 8: Button 4 (typically the "back" button on a mouse)
  /// - 16: Button 5 (typically the "forward" button on a mouse)
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// // Move the pointer to (100, 200) and press the left button
  /// await frdp.sendPointerEvent(
  ///   sessionId: session.id,
  ///   x: 100,
  ///   y: 200,
  ///   buttons: 1,
  /// );
  /// ```
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
  /// The [keyCode] parameter represents the code of the key being pressed or
  /// released, while [isDown] indicates whether the key is being pressed (`true`)
  ///  or released (`false`).
  ///
  /// Example:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// // Press the "A" key (key code 0x04 in USB HID usage)
  /// await frdp.sendKeyEvent(
  ///   sessionId: session.id,
  ///   keyCode: 0x04,
  ///   isDown: true,
  /// );
  /// // Release the "A" key
  /// await frdp.sendKeyEvent(
  ///   sessionId: session.id,
  ///   keyCode: 0x04,
  ///   isDown: false,
  /// );
  /// ```
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
