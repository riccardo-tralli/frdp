#include "FrdpFreeRdpSettingsApplier.hpp"
#include "FrdpPerformanceProfiles.hpp"

#include <algorithm>
#include <cctype>

#if FRDP_HAS_FREERDP_SETTINGS
#include <freerdp/settings_types.h>
#include <freerdp/channels/cliprdr.h>

namespace {

bool IsGfxBackend(const std::string& value) {
  std::string normalized = value;
  std::transform(normalized.begin(), normalized.end(), normalized.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return normalized == "gfx";
}

}  // namespace

bool FrdpApplyFreeRdpSettings(rdpSettings* settings, const FrdpFreeRdpConnectConfig& config) {
  if (!settings) return false;

  bool ok = true;
  auto setBool = [&](FreeRDP_Settings_Keys_Bool k, BOOL v) {
    ok = ok && freerdp_settings_set_bool(settings, k, v);
  };
  auto setU32 = [&](FreeRDP_Settings_Keys_UInt32 k, UINT32 v) {
    ok = ok && freerdp_settings_set_uint32(settings, k, v);
  };
  auto setU16 = [&](FreeRDP_Settings_Keys_UInt16 k, UINT16 v) {
    ok = ok && freerdp_settings_set_uint16(settings, k, v);
  };

  ok = ok && freerdp_settings_set_string(settings, FreeRDP_ServerHostname, config.host.c_str());
  setU32(FreeRDP_ServerPort, static_cast<UINT32>(config.port));
  ok = ok && freerdp_settings_set_string(settings, FreeRDP_Username, config.username.c_str());
  ok = ok && freerdp_settings_set_string(settings, FreeRDP_Password, config.password.c_str());
  if (!config.domain.empty()) {
    ok = ok && freerdp_settings_set_string(settings, FreeRDP_Domain, config.domain.c_str());
  }

  const FrdpPerformanceSettings perf = config.hasCustomPerformanceProfile
      ? FrdpPerformanceSettings{
            config.customPerformanceProfile.desktopWidth,
            config.customPerformanceProfile.desktopHeight,
            config.customPerformanceProfile.connectionType,
            config.customPerformanceProfile.disableWallpaper,
            config.customPerformanceProfile.disableFullWindowDrag,
            config.customPerformanceProfile.disableMenuAnimations,
            config.customPerformanceProfile.disableThemes,
            config.customPerformanceProfile.allowDesktopComposition,
            config.customPerformanceProfile.allowFontSmoothing,
        }
      : ResolvePerformanceSettings(config.performanceProfile);

  setU32(FreeRDP_DesktopWidth, perf.desktopWidth);
  setU32(FreeRDP_DesktopHeight, perf.desktopHeight);
  setU32(FreeRDP_ColorDepth, config.hasCustomPerformanceProfile
             ? config.customPerformanceProfile.colorDepth
             : 32);
  uint32_t effectiveConnectionType = perf.connectionType;
#if defined(CONNECTION_TYPE_LAN)
  if (config.enableClipboard && !config.disableClipboardPerformanceFallback) {
    // Clipboard traffic can starve rendering when the server applies
    // conservative bandwidth policies (modem/broadband profiles).
    // Force LAN policy to keep frame pacing stable while clipboard is active.
    effectiveConnectionType = CONNECTION_TYPE_LAN;
  }
#endif
  setU32(FreeRDP_ConnectionType, effectiveConnectionType);
  setU16(FreeRDP_SupportedColorDepths,
         static_cast<UINT16>(RNS_UD_32BPP_SUPPORT | RNS_UD_24BPP_SUPPORT));

  // Certificate handling
  setBool(FreeRDP_IgnoreCertificate, config.ignoreCertificate ? TRUE : FALSE);
  setBool(FreeRDP_AutoAcceptCertificate, config.ignoreCertificate ? TRUE : FALSE);
  setBool(FreeRDP_AutoDenyCertificate, FALSE);

  // Transport
  setBool(FreeRDP_NetworkAutoDetect, TRUE);
  setBool(FreeRDP_SupportMultitransport, TRUE);
  setBool(FreeRDP_AsyncUpdate, TRUE);
  setBool(FreeRDP_AsyncChannels, TRUE);
  setBool(FreeRDP_FastPathOutput, TRUE);
  setBool(FreeRDP_FastPathInput, TRUE);
  setBool(FreeRDP_CompressionEnabled, TRUE);
  setU32(FreeRDP_FrameAcknowledge, 8);

  // Cache/render hints
  setBool(FreeRDP_BitmapCacheEnabled, TRUE);
  setBool(FreeRDP_BitmapCacheV3Enabled, TRUE);
  setBool(FreeRDP_FrameMarkerCommandEnabled, TRUE);
  setBool(FreeRDP_SurfaceFrameMarkerEnabled, TRUE);
  setBool(FreeRDP_MouseMotion, TRUE);
  setBool(FreeRDP_HasExtendedMouseEvent, TRUE);
  setBool(FreeRDP_HasHorizontalWheel, TRUE);

  const bool clipboardEnabled = config.enableClipboard;
  setBool(FreeRDP_RedirectClipboard, clipboardEnabled ? TRUE : FALSE);
  if (clipboardEnabled) {
    setU32(FreeRDP_ClipboardFeatureMask, CLIPRDR_FLAG_DEFAULT_MASK);
  }

    const bool useGfxBackend = IsGfxBackend(config.renderingBackend);
    const bool gfxSurfaceCommandsEnabled =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxSurfaceCommandsEnabled
        : false;
    const bool gfxProgressive =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxProgressive
        : false;
    const bool gfxProgressiveV2 =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxProgressiveV2
        : false;
    const bool gfxPlanar =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxPlanar
        : false;
    const bool gfxH264 =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxH264
        : false;
    const bool gfxAvc444 =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxAvc444
        : false;
    const bool gfxAvc444V2 =
      useGfxBackend && config.hasCustomPerformanceProfile
        ? config.customPerformanceProfile.gfxAvc444V2
        : false;

    setBool(FreeRDP_SupportGraphicsPipeline, useGfxBackend ? TRUE : FALSE);
    setBool(FreeRDP_SurfaceCommandsEnabled, gfxSurfaceCommandsEnabled ? TRUE : FALSE);
    setBool(FreeRDP_GfxProgressive, gfxProgressive ? TRUE : FALSE);
    setBool(FreeRDP_GfxProgressiveV2, gfxProgressiveV2 ? TRUE : FALSE);
    setBool(FreeRDP_GfxPlanar, gfxPlanar ? TRUE : FALSE);
    setBool(FreeRDP_GfxH264, gfxH264 ? TRUE : FALSE);
    setBool(FreeRDP_GfxAVC444, gfxAvc444 ? TRUE : FALSE);
    setBool(FreeRDP_GfxAVC444v2, gfxAvc444V2 ? TRUE : FALSE);

  // Experience flags
  setBool(FreeRDP_DisableWallpaper, perf.disableWallpaper ? TRUE : FALSE);
  setBool(FreeRDP_DisableFullWindowDrag, perf.disableFullWindowDrag ? TRUE : FALSE);
  setBool(FreeRDP_DisableMenuAnims, perf.disableMenuAnims ? TRUE : FALSE);
  setBool(FreeRDP_DisableThemes, perf.disableThemes ? TRUE : FALSE);
  setBool(FreeRDP_AllowDesktopComposition, perf.allowDesktopComposition ? TRUE : FALSE);
  setBool(FreeRDP_AllowFontSmoothing, perf.allowFontSmoothing ? TRUE : FALSE);

  return ok;
}

#else

bool FrdpApplyFreeRdpSettings(rdpSettings* /*settings*/, const FrdpFreeRdpConnectConfig& /*config*/) {
  return false;
}

#endif
