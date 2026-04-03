import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";

import "../src/channel/frdp_platform_interface.dart";

class FrdpView extends StatelessWidget {
  final String sessionId;

  const FrdpView({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const Center(
        child: Text("FrdpView is currently available only on macOS"),
      );
    }

    final appKitView = AppKitView(
      viewType: "frdp/view",
      creationParams: <String, dynamic>{"sessionId": sessionId},
      creationParamsCodec: const StandardMessageCodec(),
    );

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
