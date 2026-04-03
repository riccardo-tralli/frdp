import "package:plugin_platform_interface/plugin_platform_interface.dart";

import "frdp_method_channel.dart";

abstract class FrdpPlatform extends PlatformInterface {
  /// Constructs a FrdpPlatform.
  FrdpPlatform() : super(token: _token);

  static final Object _token = Object();

  static FrdpPlatform _instance = MethodChannelFrdp();

  /// The default instance of [FrdpPlatform] to use.
  ///
  /// Defaults to [MethodChannelFrdp].
  static FrdpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FrdpPlatform] when
  /// they register themselves.
  static set instance(FrdpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError("platformVersion() has not been implemented");
  }

  Future<Map<dynamic, dynamic>> connect(Map<String, dynamic> configuration) {
    throw UnimplementedError("connect() has not been implemented");
  }

  Future<void> disconnect({String? sessionId}) {
    throw UnimplementedError("disconnect() has not been implemented");
  }

  Future<String> getConnectionState({String? sessionId}) {
    throw UnimplementedError("getConnectionState() has not been implemented");
  }

  Future<void> sendPointerEvent({
    required String sessionId,
    required double x,
    required double y,
    required int buttons,
  }) {
    throw UnimplementedError("sendPointerEvent() has not been implemented");
  }

  Future<void> sendKeyEvent({
    required String sessionId,
    required int keyCode,
    required bool isDown,
  }) {
    throw UnimplementedError("sendKeyEvent() has not been implemented");
  }
}
