#pragma once

#include <string>

#if __has_include(<freerdp/settings.h>)
#include <freerdp/settings.h>
#define FRDP_HAS_FREERDP_SETTINGS 1
#else
#define FRDP_HAS_FREERDP_SETTINGS 0
struct rdp_settings;
#endif

struct FrdpFreeRdpConnectConfig {
  std::string host;
  int port;
  std::string username;
  std::string password;
  std::string domain;
  bool ignoreCertificate;
  std::string performanceProfile;
};

bool FrdpApplyFreeRdpSettings(rdpSettings* settings, const FrdpFreeRdpConnectConfig& config);
