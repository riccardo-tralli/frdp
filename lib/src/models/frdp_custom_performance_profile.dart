import "frdp_connection_type.dart";
import "../channel/frdp_channel_contract.dart";

/// Fine-grained performance profile settings that give control over every FreeRDP
/// parameter related to display and user experience.
class FrdpCustomPerformanceProfile {
  /// Remote desktop width in pixels.
  final int desktopWidth;

  /// Remote desktop height in pixels.
  final int desktopHeight;

  /// RDP connection type hint, used by the server to tune protocol flags.
  final FrdpConnectionType connectionType;

  /// Colour depth in bits per pixel.  Must be one of 8, 15, 16, 24, or 32.
  final int colorDepth;

  /// Disable the remote desktop wallpaper.
  final bool disableWallpaper;

  /// Disable full-window-drag animations.
  final bool disableFullWindowDrag;

  /// Disable menu open/close animations.
  final bool disableMenuAnimations;

  /// Disable visual themes.
  final bool disableThemes;

  /// Allow desktop composition (Aero glass effects).
  final bool allowDesktopComposition;

  /// Allow font smoothing (ClearType).
  final bool allowFontSmoothing;

  /// A fully-custom performance profile that gives fine-grained control over
  /// every FreeRDP display and user-experience parameter.
  ///
  /// Use this instead of, or in addition to, the [FrdpPerformanceProfile] preset
  /// enum when you need to tune individual settings such as desktop resolution,
  /// connection type, colour depth, or individual experience flags.
  ///
  /// Pass an instance as [FrdpConnectionConfig.customPerformanceProfile].  When
  /// set, it takes precedence over [FrdpConnectionConfig.performanceProfile].
  ///
  /// Example:
  /// ```dart
  /// FrdpConnectionConfig(
  ///   host: '192.168.1.1',
  ///   username: 'user',
  ///   password: 'pass',
  ///   customPerformanceProfile: FrdpCustomPerformanceProfile(
  ///     desktopWidth: 1920,
  ///     desktopHeight: 1080,
  ///     connectionType: FrdpConnectionType.lan,
  ///     allowFontSmoothing: true,
  ///     disableWallpaper: false,
  ///   ),
  /// )
  /// ```
  const FrdpCustomPerformanceProfile({
    required this.desktopWidth,
    required this.desktopHeight,
    this.connectionType = FrdpConnectionType.broadbandLow,
    this.colorDepth = 32,
    this.disableWallpaper = true,
    this.disableFullWindowDrag = true,
    this.disableMenuAnimations = true,
    this.disableThemes = true,
    this.allowDesktopComposition = false,
    this.allowFontSmoothing = false,
  });

  /// Serialises the profile to a flat [Map] ready for the platform channel.
  Map<String, dynamic> toMap() => {
    kCustomDesktopWidthArg: desktopWidth,
    kCustomDesktopHeightArg: desktopHeight,
    kCustomConnectionTypeArg: connectionType.name,
    kCustomColorDepthArg: colorDepth,
    kCustomDisableWallpaperArg: disableWallpaper,
    kCustomDisableFullWindowDragArg: disableFullWindowDrag,
    kCustomDisableMenuAnimationsArg: disableMenuAnimations,
    kCustomDisableThemesArg: disableThemes,
    kCustomAllowDesktopCompositionArg: allowDesktopComposition,
    kCustomAllowFontSmoothingArg: allowFontSmoothing,
  };
}
