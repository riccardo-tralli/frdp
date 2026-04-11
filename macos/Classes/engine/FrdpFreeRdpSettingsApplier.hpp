#pragma once

#include <string>

#if __has_include(<freerdp/settings.h>)
#include <freerdp/settings.h>
#define FRDP_HAS_FREERDP_SETTINGS 1
#else
#define FRDP_HAS_FREERDP_SETTINGS 0
struct rdp_settings;
#endif

/// Optional, fully-custom performance settings that override the preset
/// profile when `hasCustomPerformanceProfile` is true in
/// `FrdpFreeRdpConnectConfig`.
struct FrdpCustomPerformanceConfig {
  uint32_t desktopWidth            = 1280;
  uint32_t desktopHeight           = 720;
  uint32_t connectionType          = 2;  // CONNECTION_TYPE_BROADBAND_LOW
  uint32_t colorDepth              = 32;
  bool     disableWallpaper        = true;
  bool     disableFullWindowDrag   = true;
  bool     disableMenuAnimations   = true;
  bool     disableThemes           = true;
  bool     allowDesktopComposition = false;
  bool     allowFontSmoothing      = false;
  bool     gfxSurfaceCommandsEnabled = false;
  bool     gfxProgressive            = false;
  bool     gfxProgressiveV2          = false;
  bool     gfxPlanar                 = false;
  bool     gfxH264                   = false;
  bool     gfxAvc444                 = false;
  bool     gfxAvc444V2               = false;
};

struct FrdpFreeRdpConnectConfig {
  std::string host;
  int         port;
  std::string username;
  std::string password;
  std::string domain;
  bool        ignoreCertificate;
  std::string performanceProfile;         // used only when !hasCustomPerformanceProfile
  std::string renderingBackend = "gdi";
  bool        enableClipboard = true;
  bool        hasCustomPerformanceProfile = false;
  FrdpCustomPerformanceConfig customPerformanceProfile;
};

bool FrdpApplyFreeRdpSettings(rdpSettings* settings, const FrdpFreeRdpConnectConfig& config);
