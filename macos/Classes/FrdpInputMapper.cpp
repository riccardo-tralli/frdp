#include "FrdpInputMapper.hpp"

// ---------------------------------------------------------------------------
// HID usage page 7 (keyboard / keypad): usage 0x04..0x64 → Set-1 scancode
// ---------------------------------------------------------------------------

static constexpr FrdpScancode kHidTable[] = {
  {0x1E,false},{0x30,false},{0x2E,false},{0x20,false},{0x12,false},{0x21,false},{0x22,false},{0x23,false}, // 04-0B a-h
  {0x17,false},{0x24,false},{0x25,false},{0x26,false},{0x32,false},{0x31,false},{0x18,false},{0x19,false}, // 0C-13 i-p
  {0x10,false},{0x13,false},{0x1F,false},{0x14,false},{0x16,false},{0x2F,false},{0x11,false},{0x2D,false}, // 14-1B q-x
  {0x15,false},{0x2C,false},                                                                               // 1C-1D y-z
  {0x02,false},{0x03,false},{0x04,false},{0x05,false},{0x06,false},{0x07,false},{0x08,false},{0x09,false},{0x0A,false},{0x0B,false}, // 1E-27 1-0
  {0x1C,false}, // 28 Enter
  {0x01,false}, // 29 Escape
  {0x0E,false}, // 2A Backspace
  {0x0F,false}, // 2B Tab
  {0x39,false}, // 2C Space
  {0x0C,false}, // 2D -
  {0x0D,false}, // 2E =
  {0x1A,false}, // 2F [
  {0x1B,false}, // 30 ]
  {0x2B,false}, // 31 backslash
  {0x2B,false}, // 32 non-US #
  {0x27,false}, // 33 ;
  {0x28,false}, // 34 '
  {0x29,false}, // 35 `
  {0x33,false}, // 36 ,
  {0x34,false}, // 37 .
  {0x35,false}, // 38 /
  {0x3A,false}, // 39 CapsLock
  {0x3B,false},{0x3C,false},{0x3D,false},{0x3E,false},{0x3F,false},{0x40,false},{0x41,false},{0x42,false},{0x43,false},{0x44,false},{0x57,false},{0x58,false}, // 3A-45 F1-F12
  {0x37,true},  // 46 PrintScreen
  {0x46,false}, // 47 ScrollLock
  {0x45,false}, // 48 Pause
  {0x52,true},  // 49 Insert
  {0x47,true},  // 4A Home
  {0x49,true},  // 4B PageUp
  {0x53,true},  // 4C Delete
  {0x4F,true},  // 4D End
  {0x51,true},  // 4E PageDown
  {0x4D,true},  // 4F Right
  {0x4B,true},  // 50 Left
  {0x50,true},  // 51 Down
  {0x48,true},  // 52 Up
  {0x45,true},  // 53 NumLock
  {0x35,true},  // 54 KP /
  {0x37,false}, // 55 KP *
  {0x4A,false}, // 56 KP -
  {0x4E,false}, // 57 KP +
  {0x1C,true},  // 58 KP Enter
  {0x4F,false},{0x50,false},{0x51,false},{0x4B,false},{0x4C,false},{0x4D,false},{0x47,false},{0x48,false},{0x49,false},{0x52,false}, // 59-62 KP 1-9, KP 0
  {0x53,false}, // 63 KP .
  {0x56,false}, // 64 non-US backslash
};
static constexpr int kHidTableBase = 0x04;
static constexpr int kHidTableSize = static_cast<int>(sizeof(kHidTable) / sizeof(kHidTable[0]));

// HID modifier keys 0xE0-0xE7
static constexpr FrdpScancode kHidModTable[] = {
  {0x1D, false}, // E0 LCtrl
  {0x2A, false}, // E1 LShift
  {0x38, false}, // E2 LAlt
  {0x5B, true},  // E3 LMeta
  {0x1D, true},  // E4 RCtrl
  {0x36, false}, // E5 RShift
  {0x38, true},  // E6 RAlt
  {0x5C, true},  // E7 RMeta
};

FrdpScancode FrdpHidUsageToScancode(int usbHidUsage) {
  const int page  = (usbHidUsage >> 16) & 0xFFFF;
  const int usage = usbHidUsage & 0xFFFF;

  if (page != 0x0007) return {0, false}; // keyboard/keypad page only

  if (usage >= 0xE0 && usage <= 0xE7) {
    return kHidModTable[usage - 0xE0];
  }

  if (usage < kHidTableBase || usage >= kHidTableBase + kHidTableSize) return {0, false};
  return kHidTable[usage - kHidTableBase];
}

// ---------------------------------------------------------------------------
// macOS virtual keycode → Set-1 scancode
// ---------------------------------------------------------------------------

FrdpScancode FrdpMacKeycodeToScancode(int keyCode) {
  switch (keyCode) {
    case   0: return {0x1E, false}; // A
    case   1: return {0x1F, false}; // S
    case   2: return {0x20, false}; // D
    case   3: return {0x21, false}; // F
    case   4: return {0x23, false}; // H
    case   5: return {0x22, false}; // G
    case   6: return {0x2C, false}; // Z
    case   7: return {0x2D, false}; // X
    case   8: return {0x2E, false}; // C
    case   9: return {0x2F, false}; // V
    case  11: return {0x30, false}; // B
    case  12: return {0x10, false}; // Q
    case  13: return {0x11, false}; // W
    case  14: return {0x12, false}; // E
    case  15: return {0x13, false}; // R
    case  16: return {0x15, false}; // Y
    case  17: return {0x14, false}; // T
    case  18: return {0x02, false}; // 1
    case  19: return {0x03, false}; // 2
    case  20: return {0x04, false}; // 3
    case  21: return {0x05, false}; // 4
    case  22: return {0x07, false}; // 6
    case  23: return {0x06, false}; // 5
    case  24: return {0x0D, false}; // =
    case  25: return {0x0A, false}; // 9
    case  26: return {0x08, false}; // 7
    case  27: return {0x0C, false}; // -
    case  28: return {0x09, false}; // 8
    case  29: return {0x0B, false}; // 0
    case  30: return {0x1B, false}; // ]
    case  31: return {0x18, false}; // O
    case  32: return {0x16, false}; // U
    case  33: return {0x1A, false}; // [
    case  34: return {0x17, false}; // I
    case  35: return {0x19, false}; // P
    case  36: return {0x1C, false}; // Return
    case  37: return {0x26, false}; // L
    case  38: return {0x24, false}; // J
    case  39: return {0x28, false}; // '
    case  40: return {0x25, false}; // K
    case  41: return {0x27, false}; // ;
    case  42: return {0x2B, false}; // backslash
    case  43: return {0x33, false}; // ,
    case  44: return {0x35, false}; // /
    case  45: return {0x31, false}; // N
    case  46: return {0x32, false}; // M
    case  47: return {0x34, false}; // .
    case  48: return {0x0F, false}; // Tab
    case  49: return {0x39, false}; // Space
    case  50: return {0x29, false}; // `
    case  51: return {0x0E, false}; // Backspace
    case  53: return {0x01, false}; // Escape
    case  54: return {0x5C, true};  // Right Command
    case  55: return {0x5B, true};  // Left Command
    case  56: return {0x2A, false}; // Left Shift
    case  57: return {0x3A, false}; // CapsLock
    case  58: return {0x38, false}; // Left Option
    case  59: return {0x1D, false}; // Left Control
    case  60: return {0x36, false}; // Right Shift
    case  61: return {0x38, true};  // Right Option
    case  62: return {0x1D, true};  // Right Control
    case  65: return {0x53, false}; // Keypad .
    case  67: return {0x37, false}; // Keypad *
    case  69: return {0x4E, false}; // Keypad +
    case  71: return {0x45, false}; // Keypad Clear / NumLock
    case  75: return {0x35, true};  // Keypad /
    case  76: return {0x1C, true};  // Keypad Enter
    case  78: return {0x4A, false}; // Keypad -
    case  81: return {0x0D, false}; // Keypad =
    case  82: return {0x52, false}; // Keypad 0
    case  83: return {0x4F, false}; // Keypad 1
    case  84: return {0x50, false}; // Keypad 2
    case  85: return {0x51, false}; // Keypad 3
    case  86: return {0x4B, false}; // Keypad 4
    case  87: return {0x4C, false}; // Keypad 5
    case  88: return {0x4D, false}; // Keypad 6
    case  89: return {0x47, false}; // Keypad 7
    case  91: return {0x48, false}; // Keypad 8
    case  92: return {0x49, false}; // Keypad 9
    case  96: return {0x3F, false}; // F5
    case  97: return {0x40, false}; // F6
    case  98: return {0x41, false}; // F7
    case  99: return {0x3D, false}; // F3
    case 100: return {0x42, false}; // F8
    case 101: return {0x43, false}; // F9
    case 103: return {0x57, false}; // F11
    case 109: return {0x44, false}; // F10
    case 111: return {0x58, false}; // F12
    case 114: return {0x52, true};  // Help / Insert
    case 115: return {0x47, true};  // Home
    case 116: return {0x49, true};  // PageUp
    case 117: return {0x53, true};  // Forward Delete
    case 118: return {0x3E, false}; // F4
    case 119: return {0x4F, true};  // End
    case 120: return {0x3C, false}; // F2
    case 121: return {0x51, true};  // PageDown
    case 122: return {0x3B, false}; // F1
    case 123: return {0x4B, true};  // Left
    case 124: return {0x4D, true};  // Right
    case 125: return {0x50, true};  // Down
    case 126: return {0x48, true};  // Up
    default:  return {0, false};
  }
}
