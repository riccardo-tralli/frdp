import "../channel/frdp_channel_contract.dart";

/// The connection state of a remote desktop session.
enum FrdpConnectionState {
  /// The session is currently disconnected.
  disconnected,

  /// The session is in the process of connecting.
  connecting,

  /// The session is currently connected.
  connected,

  /// The session has encountered an error.
  error,
}

/// Parses a raw connection state string into a [FrdpConnectionState] enum value.
FrdpConnectionState parseFrdpConnectionState(String? rawState) =>
    switch (rawState) {
      kDisconnectedState => FrdpConnectionState.disconnected,
      kConnectingState => FrdpConnectionState.connecting,
      kConnectedState => FrdpConnectionState.connected,
      kErrorState => FrdpConnectionState.error,
      _ => FrdpConnectionState.disconnected,
    };
