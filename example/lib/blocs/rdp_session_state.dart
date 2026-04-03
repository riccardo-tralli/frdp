part of "rdp_session_bloc.dart";

sealed class RdpSessionState {
  const RdpSessionState();
}

final class RdpSessionDisconnectedState extends RdpSessionState {
  const RdpSessionDisconnectedState();
}

final class RdpSessionConnectingState extends RdpSessionState {
  const RdpSessionConnectingState();
}

final class RdpSessionConnectedState extends RdpSessionState {
  final String id;

  const RdpSessionConnectedState(this.id);
}

final class RdpSessionErrorState extends RdpSessionState {
  final String message;

  const RdpSessionErrorState(this.message);
}
