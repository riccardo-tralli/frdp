import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../src/channel/frdp_platform_interface.dart";

/// A widget that displays the remote desktop session.
/// It uses an [AppKitView] on macOS to render the RDP session, and shows a
/// placeholder message on other platforms.
class FrdpView extends StatelessWidget {
  /// The unique identifier of the RDP session.
  final String sessionId;

  /// Constructs a [FrdpView] instance with the given [sessionId].
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
      creationParams: <String, dynamic>{"sessionId": sessionId},
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
