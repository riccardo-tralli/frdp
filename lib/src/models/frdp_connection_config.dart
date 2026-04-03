import "frdp_performance_profile.dart";
import "../channel/frdp_channel_contract.dart";

class FrdpConnectionConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String? domain;
  final bool ignoreCertificate;
  final FrdpPerformanceProfile performanceProfile;
  final int? connectTimeoutMs;

  const FrdpConnectionConfig({
    required this.host,
    this.port = 3389,
    required this.username,
    required this.password,
    this.domain,
    this.ignoreCertificate = false,
    this.performanceProfile = FrdpPerformanceProfile.medium,
    this.connectTimeoutMs,
  });

  Map<String, dynamic> toMap() {
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, kHostArg, "Host cannot be empty");
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(
        port,
        kPortArg,
        "Port must be in range 1-65535",
      );
    }
    if (username.trim().isEmpty) {
      throw ArgumentError.value(
        username,
        kUsernameArg,
        "Username cannot be empty",
      );
    }
    if (password.trim().isEmpty) {
      throw ArgumentError.value(
        password,
        kPasswordArg,
        "Password cannot be empty",
      );
    }
    if (connectTimeoutMs != null && connectTimeoutMs! <= 0) {
      throw ArgumentError.value(
        connectTimeoutMs,
        kConnectTimeoutMsArg,
        "Timeout must be > 0",
      );
    }

    return <String, dynamic>{
      kHostArg: host,
      kPortArg: port,
      kUsernameArg: username,
      kPasswordArg: password,
      kDomainArg: domain,
      kIgnoreCertificateArg: ignoreCertificate,
      kPerformanceProfileArg: performanceProfile.name,
      if (connectTimeoutMs != null) kConnectTimeoutMsArg: connectTimeoutMs,
    };
  }
}
