import "../channel/frdp_channel_contract.dart";

enum FrdpConnectionState { disconnected, connecting, connected, error }

FrdpConnectionState parseFrdpConnectionState(String? rawState) =>
    switch (rawState) {
      kDisconnectedState => FrdpConnectionState.disconnected,
      kConnectingState => FrdpConnectionState.connecting,
      kConnectedState => FrdpConnectionState.connected,
      kErrorState => FrdpConnectionState.error,
      _ => FrdpConnectionState.disconnected,
    };
