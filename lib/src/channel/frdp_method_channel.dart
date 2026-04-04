import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

import "frdp_platform_interface.dart";
import "frdp_channel_contract.dart";

/// An implementation of [FrdpPlatform] that uses method channels.
class MethodChannelFrdp extends FrdpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(kFrdpChannelName);

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      kGetPlatformVersionMethod,
    );
    return version;
  }

  @override
  Future<Map<dynamic, dynamic>> connect(
    Map<String, dynamic> configuration,
  ) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      kConnectMethod,
      configuration,
    );

    return result ?? <dynamic, dynamic>{};
  }

  @override
  Future<void> disconnect([String? sessionId]) {
    return methodChannel.invokeMethod<void>(
      kDisconnectMethod,
      <String, dynamic>{kSessionIdArg: sessionId},
    );
  }

  @override
  Future<String> getConnectionState([String? sessionId]) async {
    final result = await methodChannel.invokeMethod<String>(
      kGetConnectionStateMethod,
      <String, dynamic>{kSessionIdArg: sessionId},
    );
    return result ?? kDisconnectedState;
  }

  @override
  Future<void> sendPointerEvent({
    required String sessionId,
    required double x,
    required double y,
    required int buttons,
  }) {
    return methodChannel.invokeMethod<void>(
      kSendPointerEventMethod,
      <String, dynamic>{
        kSessionIdArg: sessionId,
        kXArg: x,
        kYArg: y,
        kButtonsArg: buttons,
      },
    );
  }

  @override
  Future<void> sendKeyEvent({
    required String sessionId,
    required int keyCode,
    required bool isDown,
  }) {
    return methodChannel.invokeMethod<void>(
      kSendKeyEventMethod,
      <String, dynamic>{
        kSessionIdArg: sessionId,
        kKeyCodeArg: keyCode,
        kIsDownArg: isDown,
      },
    );
  }
}
