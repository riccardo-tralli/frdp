#pragma once

#include <cstdint>

// ---------------------------------------------------------------------------
// FrdpInputMapper
//
// Stateless translation utilities between platform key encodings and the
// PC/AT Set-1 scancodes used by FreeRDP.
//
// All functions are pure and thread-safe.
// ---------------------------------------------------------------------------

struct FrdpScancode {
  uint8_t  scancode;  // PC/AT Set-1 scancode byte
  bool     extended;  // true → prepend 0xE0 prefix (KBD_FLAGS_EXTENDED)
};

/// Translate a Flutter physicalKey.usbHidUsage value (page << 16 | usage)
/// to a PC/AT scancode.  Returns {0, false} for unmapped keys.
FrdpScancode FrdpHidUsageToScancode(int usbHidUsage);

/// Translate a macOS virtual keycode (NSEvent.keyCode) to a PC/AT scancode.
/// Returns {0, false} for unmapped keys.
FrdpScancode FrdpMacKeycodeToScancode(int keyCode);
