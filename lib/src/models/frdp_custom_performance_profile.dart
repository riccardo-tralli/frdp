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

  /// Enable RDP surface commands when using the GFX backend.
  final bool gfxSurfaceCommandsEnabled;

  /// Enable progressive GFX codec when using the GFX backend.
  final bool gfxProgressive;

  /// Enable progressive v2 GFX codec when using the GFX backend.
  final bool gfxProgressiveV2;

  /// Enable planar GFX codec when using the GFX backend.
  final bool gfxPlanar;

  /// Enable H.264 GFX codec when using the GFX backend.
  final bool gfxH264;

  /// Enable AVC444 GFX mode when using the GFX backend.
  final bool gfxAvc444;

  /// Enable AVC444v2 GFX mode when using the GFX backend.
  final bool gfxAvc444V2;

  /// A fully-custom performance profile that gives fine-grained control over
  /// every FreeRDP display and user-experience parameter.
  ///
  /// The [desktopWidth] and [desktopHeight] parameters are required, while the
  /// other parameters have default values.
  ///
  /// [FrdpConnectionConfig.performanceProfile] must be set to
  /// [FrdpPerformanceProfile.custom] in the [FrdpConnectionConfig].
  ///
  /// Note that some parameters (e.g. GFX codec settings) will only have an effect
  /// if the rendering backend supports them (active only with the GFX backend).
  ///
  /// Example:
  /// ```dart
  /// FrdpConnectionConfig(
  ///   host: '192.168.1.1',
  ///   username: 'user',
  ///   password: 'pass',
  ///   performanceProfile: FrdpPerformanceProfile.custom,
  ///   customPerformanceProfile: FrdpCustomPerformanceProfile(
  ///     desktopWidth: 1920,
  ///     desktopHeight: 1080,
  ///     connectionType: FrdpConnectionType.lan,
  ///     allowFontSmoothing: true,
  ///     disableWallpaper: false,
  ///   ),
  /// )
  /// // GFX codec settings example:
  /// FrdpConnectionConfig(
  ///   host: '192.168.1.1',
  ///   username: 'user',
  ///   password: 'pass',
  ///   renderingBackend: FrdpRenderingBackend.gfx,
  ///   performanceProfile: FrdpPerformanceProfile.custom,
  ///   customPerformanceProfile: FrdpCustomPerformanceProfile(
  ///     desktopWidth: 1920,
  ///     desktopHeight: 1080,
  ///     gfxH264: true,
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
    this.gfxSurfaceCommandsEnabled = false,
    this.gfxProgressive = false,
    this.gfxProgressiveV2 = false,
    this.gfxPlanar = false,
    this.gfxH264 = false,
    this.gfxAvc444 = false,
    this.gfxAvc444V2 = false,
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
    kCustomGfxSurfaceCommandsEnabledArg: gfxSurfaceCommandsEnabled,
    kCustomGfxProgressiveArg: gfxProgressive,
    kCustomGfxProgressiveV2Arg: gfxProgressiveV2,
    kCustomGfxPlanarArg: gfxPlanar,
    kCustomGfxH264Arg: gfxH264,
    kCustomGfxAvc444Arg: gfxAvc444,
    kCustomGfxAvc444V2Arg: gfxAvc444V2,
  };
}
