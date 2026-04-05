/// Defines the performance profiles for the RDP session, which can be used to
/// optimize the session based on the network conditions and user preferences.
enum FrdpPerformanceProfile {
  /// Low performance profile (best for low bandwidth connections).
  low,

  /// Medium performance profile (balanced performance and quality, default).
  medium,

  /// High performance profile (best for high performance connections).
  high,

  /// Custom performance profile, where all settings are configured manually via
  /// [FrdpCustomPerformanceProfile].  When selected, the [customPerformanceProfile]
  /// field of [FrdpConnectionConfig] must be set with the desired settings.
  custom,
}
