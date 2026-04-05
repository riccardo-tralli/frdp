import "frdp_custom_performance_profile.dart";
import "frdp_performance_profile.dart";
import "../channel/frdp_channel_contract.dart";

/// Configuration for establishing a remote desktop connection, including
/// connection details, authentication credentials, and performance settings.
class FrdpConnectionConfig {
  /// The host or IP address of the remote desktop to connect to.
  final String host;

  /// The port number to use for the connection (default is 3389).
  final int port;

  /// The username to use for authentication with the remote desktop.
  final String username;

  /// The password to use for authentication with the remote desktop.
  final String password;

  /// The domain to use for authentication with the remote desktop (optional).
  final String? domain;

  /// Whether to ignore certificate errors when connecting to the remote
  /// desktop (default is false).
  final bool ignoreCertificate;

  /// The performance profile to use for the connection (default is medium).
  ///
  /// Use [FrdpPerformanceProfile.custom] together with
  /// [customPerformanceProfile] to configure every FreeRDP parameter
  /// individually.
  final FrdpPerformanceProfile performanceProfile;

  /// Fine-grained settings used when [performanceProfile] is
  /// [FrdpPerformanceProfile.custom].  Must be non-null in that case;
  /// ignored for all other profiles.
  final FrdpCustomPerformanceProfile? customPerformanceProfile;

  /// The connection timeout in milliseconds (optional).
  final int? connectTimeoutMs;

  /// Configuration for establishing a remote desktop connection.
  ///
  /// The [host], [username], and [password] fields are required, while the
  /// others have default values or are optional.
  const FrdpConnectionConfig({
    required this.host,
    this.port = 3389,
    required this.username,
    required this.password,
    this.domain,
    this.ignoreCertificate = false,
    this.performanceProfile = FrdpPerformanceProfile.medium,
    this.customPerformanceProfile,
    this.connectTimeoutMs,
  });

  /// Converts the [FrdpConnectionConfig] instance to a [Map] for use in
  /// platform channels.
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
    if (performanceProfile == FrdpPerformanceProfile.custom &&
        customPerformanceProfile == null) {
      throw ArgumentError(
        "customPerformanceProfile must be set when performanceProfile is "
        "FrdpPerformanceProfile.custom",
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
      if (performanceProfile == FrdpPerformanceProfile.custom)
        ...customPerformanceProfile!.toMap(),
      if (connectTimeoutMs != null) kConnectTimeoutMsArg: connectTimeoutMs,
    };
  }
}
