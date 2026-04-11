import "package:flutter/services.dart";
import "package:frdp/src/models/frdp_clipboard_event.dart";

import "../channel/frdp_channel_contract.dart";

/// Bidirectional clipboard bridge between device and the remote RDP session.
///
///
class FrdpClipboard {
  const FrdpClipboard._();

  static const _eventChannel = EventChannel(kClipboardEventsEvent);
  static const _methodChannel = MethodChannel(kFrdpChannelName);

  /// Broadcasts [FrdpClipboardEvent] instances whenever the remote host
  /// places new text on its clipboard.
  ///
  /// Subscribe once and keep the subscription alive for the duration of the
  /// session:
  /// ```dart
  /// final sub = FrdpClipboard.remoteChanges.listen((event) {
  ///   print("Remote clipboard: ${event.text}");
  /// });
  /// ```
  static Stream<FrdpClipboardEvent> get remoteChanges => _eventChannel
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return FrdpClipboardEvent(
          sessionId: (map[kSessionIdArg] as String?) ?? "",
          text: (map[kClipboardTextArg] as String?) ?? "",
        );
      })
      .where((e) => e.text.isNotEmpty);

  /// Explicitly push [text] to the remote clipboard for [sessionId].
  ///
  /// Use this method only when you need
  /// programmatic control (e.g. a "Copy to remote" button in the UI).
  static Future<void> sendToRemote({
    required String sessionId,
    required String text,
  }) => _methodChannel.invokeMethod<void>(
    kSendClipboardTextMethod,
    <String, dynamic>{kSessionIdArg: sessionId, kClipboardTextArg: text},
  );
}
