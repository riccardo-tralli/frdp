#include "FrdpFreeRdpSettingsApplier.hpp"
#include "FrdpPerformanceProfiles.hpp"

#if FRDP_HAS_FREERDP_SETTINGS
#include <freerdp/settings_types.h>

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

  const FrdpPerformanceSettings perf = ResolvePerformanceSettings(config.performanceProfile);

  setU32(FreeRDP_DesktopWidth, perf.desktopWidth);
  setU32(FreeRDP_DesktopHeight, perf.desktopHeight);
  setU32(FreeRDP_ColorDepth, 32);
  setU32(FreeRDP_ConnectionType, perf.connectionType);
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

  // GDI-based framebuffer path — disable GPU pipeline
  setBool(FreeRDP_SupportGraphicsPipeline, FALSE);
  setBool(FreeRDP_SurfaceCommandsEnabled, FALSE);
  setBool(FreeRDP_GfxProgressive, FALSE);
  setBool(FreeRDP_GfxProgressiveV2, FALSE);
  setBool(FreeRDP_GfxPlanar, FALSE);
  setBool(FreeRDP_GfxH264, FALSE);
  setBool(FreeRDP_GfxAVC444, FALSE);
  setBool(FreeRDP_GfxAVC444v2, FALSE);

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
