#include "FrdpPerformanceProfiles.hpp"

#include <algorithm>
#include <cctype>

#if __has_include(<freerdp/settings_types.h>)
#include <freerdp/settings_types.h>
#else
#define CONNECTION_TYPE_MODEM 0
#define CONNECTION_TYPE_BROADBAND_LOW 0
#define CONNECTION_TYPE_LAN 0
#endif

FrdpPerformanceSettings ResolvePerformanceSettings(const std::string& performanceProfile) {
  std::string normalized = performanceProfile;
  std::transform(normalized.begin(), normalized.end(), normalized.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

  if (normalized == "low") {
    return {
        1024,
        576,
        CONNECTION_TYPE_MODEM,
        true,
        true,
        true,
        true,
        false,
        false,
    };
  }

  if (normalized == "high") {
    return {
        1600,
        900,
        CONNECTION_TYPE_LAN,
        false,
        false,
        false,
        false,
        true,
        true,
    };
  }

  // Default "medium" profile.
  return {
      1280,
      720,
      CONNECTION_TYPE_BROADBAND_LOW,
      true,
      true,
      true,
      true,
      false,
      false,
  };
}
