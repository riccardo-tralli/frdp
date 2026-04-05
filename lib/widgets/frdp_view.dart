import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../src/channel/frdp_channel_contract.dart";
import "../src/channel/frdp_platform_interface.dart";

/// A widget that displays the remote desktop session.
class FrdpView extends StatelessWidget {
  /// The unique identifier of the RDP session.
  final String sessionId;

  /// Displays the remote desktop session associated with the given [sessionId].
  ///
  /// It also captures keyboard and mouse events and forwards them to the native side.
  ///
  /// The [sessionId] parameter is required to identify which RDP session to
  /// display and interact with. Make sure to provide a valid session ID obtained
  /// from a successful connection.
  ///
  /// Example usage:
  /// ```dart
  /// final frdp = Frdp();
  /// final session = await frdp.connect(FrdpConnectionConfig(
  ///   host: "192.168.1.1",
  ///   username: "user",
  ///   password: "password",
  /// ));
  /// final frdpView = FrdpView(sessionId: session.id);
  /// ```
  const FrdpView({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            "FrdpView is currently available only on macOS",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // On macOS, use an AppKitView to render the RDP session.
    final appKitView = AppKitView(
      viewType: "frdp/view",
      creationParams: <String, dynamic>{kSessionIdArg: sessionId},
      creationParamsCodec: const StandardMessageCodec(),
    );

    // Wrap the AppKitView with a Focus and Listener to capture keyboard and
    // mouse events and forward them to the native side.
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final bool isDown = event is KeyDownEvent || event is KeyRepeatEvent;
        if (event is! KeyDownEvent &&
            event is! KeyRepeatEvent &&
            event is! KeyUpEvent) {
          return KeyEventResult.ignored;
        }

        FrdpPlatform.instance.sendKeyEvent(
          sessionId: sessionId,
          keyCode: event.physicalKey.usbHidUsage,
          isDown: isDown,
        );

        return KeyEventResult.handled;
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _forwardPointer,
        onPointerMove: _forwardPointer,
        onPointerUp: _forwardPointer,
        child: appKitView,
      ),
    );
  }

  void _forwardPointer(PointerEvent event) {
    FrdpPlatform.instance.sendPointerEvent(
      sessionId: sessionId,
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      buttons: event.buttons,
    );
  }
}
