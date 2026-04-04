import "package:plugin_platform_interface/plugin_platform_interface.dart";

import "frdp_method_channel.dart";

abstract class FrdpPlatform extends PlatformInterface {
  /// Constructs a FrdpPlatform.
  FrdpPlatform() : super(token: _token);

  /// The token used for verifying the identity of platform implementations.
  static final Object _token = Object();

  /// The default instance of [FrdpPlatform] to use.
  static FrdpPlatform _instance = MethodChannelFrdp();

  /// The default instance of [FrdpPlatform] to use.
  static FrdpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FrdpPlatform] when
  /// they register themselves.
  static set instance(FrdpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a [String] containing the current platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError("platformVersion() has not been implemented");
  }

  /// Connects to a remote desktop using the provided [configuration].
  ///
  /// The [configuration] parameter should include all necessary information for
  /// establishing the connection, such as host, port, username, password, and
  /// any additional options.
  ///
  /// Returns a [Map] representing the established session, which may include
  /// details such as session ID, connection status, and any relevant metadata.
  ///
  /// Throws an error if the connection fails.
  Future<Map<dynamic, dynamic>> connect(Map<String, dynamic> configuration) {
    throw UnimplementedError("connect() has not been implemented");
  }

  /// Disconnects from the remote desktop session with the optional [sessionId].
  ///
  /// If [sessionId] is not provided, the current session will be disconnected.
  ///
  /// Throws an error if the disconnection fails or if there is no active
  /// session to disconnect from.
  Future<void> disconnect([String? sessionId]) {
    throw UnimplementedError("disconnect() has not been implemented");
  }

  /// Retrieves the current connection state of the remote desktop session with
  /// the optional [sessionId].
  ///
  /// Returns a [String] indicating the current state of the connection, such as
  /// "connected", "disconnected", "connecting", or "error".
  ///
  /// Throws an error if the state retrieval fails or if there is no active
  /// session with the specified [sessionId].
  Future<String> getConnectionState([String? sessionId]) {
    throw UnimplementedError("getConnectionState() has not been implemented");
  }

  /// Sends a pointer event to the remote desktop session with the specified [sessionId].
  ///
  /// The [x] and [y] parameters specify the coordinates of the pointer event.
  /// The [buttons] parameter specifies the state of the mouse buttons.
  ///
  /// Throws an error if the pointer event cannot be sent.
  Future<void> sendPointerEvent({
    required String sessionId,
    required double x,
    required double y,
    required int buttons,
  }) {
    throw UnimplementedError("sendPointerEvent() has not been implemented");
  }

  /// Sends a key event to the remote desktop session with the specified [sessionId].
  ///
  /// The [keyCode] parameter specifies the code of the key event, while [isDown]
  /// indicates whether the key is being pressed down or released.
  ///
  /// Throws an error if the key event cannot be sent.
  Future<void> sendKeyEvent({
    required String sessionId,
    required int keyCode,
    required bool isDown,
  }) {
    throw UnimplementedError("sendKeyEvent() has not been implemented");
  }
}
