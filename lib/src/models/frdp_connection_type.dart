/// The RDP connection type, which hints to the server the network conditions
/// so it can tune protocol flags and disable bandwidth-heavy features
/// accordingly.
///
/// Maps to the `CONNECTION_TYPE_*` constants in the FreeRDP settings API.
enum FrdpConnectionType {
  /// Modem — very low bandwidth (CONNECTION_TYPE_MODEM).
  modem,

  /// Broadband low — low bandwidth broadband, default for the medium preset
  /// (CONNECTION_TYPE_BROADBAND_LOW).
  broadbandLow,

  /// Broadband high — higher bandwidth broadband
  /// (CONNECTION_TYPE_BROADBAND_HIGH).
  broadbandHigh,

  /// Satellite — high latency, medium bandwidth (CONNECTION_TYPE_SATELLITE).
  satellite,

  /// WAN — wide area network (CONNECTION_TYPE_WAN).
  wan,

  /// LAN — local area network, default for the high preset
  /// (CONNECTION_TYPE_LAN).
  lan,

  /// Auto-detect — let the server negotiate the connection type
  /// (CONNECTION_TYPE_AUTODETECT).
  autoDetect,
}
