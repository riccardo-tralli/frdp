#pragma once

#include <cstdint>
#include <string>

struct FrdpPerformanceSettings {
  uint32_t desktopWidth;
  uint32_t desktopHeight;
  uint32_t connectionType;
  bool disableWallpaper;
  bool disableFullWindowDrag;
  bool disableMenuAnims;
  bool disableThemes;
  bool allowDesktopComposition;
  bool allowFontSmoothing;
};

FrdpPerformanceSettings ResolvePerformanceSettings(const std::string& performanceProfile);
