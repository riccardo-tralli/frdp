part of "rdp_session_bloc.dart";

sealed class RdpSessionEvent {
  const RdpSessionEvent();
}

final class ConnectRdpSessionEvent extends RdpSessionEvent {
  final String host;
  final int port;
  final String username;
  final String password;
  final String? domain;
  final bool ignoreCertificate;
  final FrdpPerformanceProfile performanceProfile;

  const ConnectRdpSessionEvent({
    required this.host,
    this.port = 3389,
    required this.username,
    required this.password,
    this.domain,
    this.ignoreCertificate = false,
    this.performanceProfile = FrdpPerformanceProfile.medium,
  });
}

final class DisconnectRdpSessionEvent extends RdpSessionEvent {
  const DisconnectRdpSessionEvent();
}
