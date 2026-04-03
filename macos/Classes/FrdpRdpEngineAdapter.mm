#import "FrdpRdpEngineAdapter.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cmath>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <netdb.h>
#include <string>
#include <thread>
#include <unordered_map>

#if __has_include(<freerdp/freerdp.h>)
#define FRDP_HAS_FREERDP 1
#include <freerdp/client.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/settings.h>
#include <freerdp/settings_types.h>
#else
#define FRDP_HAS_FREERDP 0
#endif

@interface FrdpFrameView : NSView
- (void)updateImage:(CGImageRef)image;
@end

static void FrdpReleaseFrameBuffer(void* info, const void* data, size_t size) {
  (void)info;
  (void)size;
  free(const_cast<void*>(data));
}

@implementation FrdpFrameView {
  CGImageRef _image;
}

- (instancetype)init {
  self = [super initWithFrame:NSMakeRect(0, 0, 640, 360)];
  if (self) {
    _image = nullptr;
    self.wantsLayer = YES;
    self.layer.contentsGravity = kCAGravityResize;
  }
  return self;
}

- (void)dealloc {
  if (_image != nullptr) {
    CGImageRelease(_image);
    _image = nullptr;
  }
}

- (void)updateImage:(CGImageRef)image {
  if (image == nullptr) {
    return;
  }

  if (_image != nullptr) {
    CGImageRelease(_image);
  }
  _image = CGImageRetain(image);
  self.layer.contents = (__bridge id)_image;
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  if (_image == nullptr) {
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
  }
}

@end

class FrdpEngineCore {
 public:
  using FrameCallback = std::function<void(const uint8_t*, int, int, int)>;

  FrdpEngineCore() = default;

  ~FrdpEngineCore() { disconnect(); }

  bool connect(const std::string& host,
               int port,
               const std::string& username,
               const std::string& password,
               const std::string& domain,
               bool ignoreCertificate,
               const std::string& performanceProfile,
               std::string& errorMessage) {
    if (running_.load()) {
      errorMessage = "RDP session is already running.";
      return false;
    }

    std::string normalizedHost = host;
    if (!normalizeHost(normalizedHost, errorMessage)) {
      return false;
    }

    if (!validateHostResolvable(normalizedHost, port, errorMessage)) {
      return false;
    }

#if FRDP_HAS_FREERDP
    instance_.reset(freerdp_new());
    if (!instance_) {
      errorMessage = "Unable to allocate FreeRDP instance.";
      return false;
    }

    instance_->PreConnect = &FrdpEngineCore::onPreConnect;
    instance_->PostConnect = &FrdpEngineCore::onPostConnect;

    if (!freerdp_context_new(instance_.get())) {
      errorMessage = "Unable to allocate FreeRDP context.";
      instance_.reset();
      return false;
    }

    auto* settings = (instance_->context != nullptr) ? instance_->context->settings : nullptr;
    if (settings == nullptr) {
      errorMessage = "FreeRDP settings are not initialized.";
      freerdp_context_free(instance_.get());
      instance_.reset();
      return false;
    }

    bool settingsOk = true;
    auto setBool = [&](FreeRDP_Settings_Keys_Bool key, BOOL value) {
      settingsOk = settingsOk && freerdp_settings_set_bool(settings, key, value);
    };
    auto setU32 = [&](FreeRDP_Settings_Keys_UInt32 key, UINT32 value) {
      settingsOk = settingsOk && freerdp_settings_set_uint32(settings, key, value);
    };
    auto setU16 = [&](FreeRDP_Settings_Keys_UInt16 key, UINT16 value) {
      settingsOk = settingsOk && freerdp_settings_set_uint16(settings, key, value);
    };

    settingsOk = settingsOk && freerdp_settings_set_string(settings, FreeRDP_ServerHostname, normalizedHost.c_str());
    setU32(FreeRDP_ServerPort, static_cast<UINT32>(port));
    settingsOk = settingsOk && freerdp_settings_set_string(settings, FreeRDP_Username, username.c_str());
    settingsOk = settingsOk && freerdp_settings_set_string(settings, FreeRDP_Password, password.c_str());
    if (!domain.empty()) {
      settingsOk = settingsOk && freerdp_settings_set_string(settings, FreeRDP_Domain, domain.c_str());
    }

    // Force a stable pixel format negotiation for our GDI-based framebuffer path.
    std::string profile = performanceProfile;
    std::transform(profile.begin(), profile.end(), profile.begin(), [](unsigned char c) {
      return static_cast<char>(std::tolower(c));
    });

    UINT32 desktopWidth = 1280;
    UINT32 desktopHeight = 720;
    UINT32 connectionType = CONNECTION_TYPE_BROADBAND_LOW;
    BOOL disableWallpaper = TRUE;
    BOOL disableFullWindowDrag = TRUE;
    BOOL disableMenuAnims = TRUE;
    BOOL disableThemes = TRUE;
    BOOL allowDesktopComposition = FALSE;
    BOOL allowFontSmoothing = FALSE;

    if (profile == "low") {
      desktopWidth = 1024;
      desktopHeight = 576;
      connectionType = CONNECTION_TYPE_MODEM;
    } else if (profile == "high") {
      desktopWidth = 1600;
      desktopHeight = 900;
      connectionType = CONNECTION_TYPE_LAN;
      disableWallpaper = FALSE;
      disableFullWindowDrag = FALSE;
      disableMenuAnims = FALSE;
      disableThemes = FALSE;
      allowDesktopComposition = TRUE;
      allowFontSmoothing = TRUE;
    }

    setU32(FreeRDP_DesktopWidth, desktopWidth);
    setU32(FreeRDP_DesktopHeight, desktopHeight);
    setU32(FreeRDP_ColorDepth, 32);
    setU32(FreeRDP_ConnectionType, connectionType);
    setU16(FreeRDP_SupportedColorDepths, static_cast<UINT16>(RNS_UD_32BPP_SUPPORT | RNS_UD_24BPP_SUPPORT));

    // Certificate handling.
    setBool(FreeRDP_IgnoreCertificate, ignoreCertificate ? TRUE : FALSE);
    setBool(FreeRDP_AutoAcceptCertificate, ignoreCertificate ? TRUE : FALSE);
    setBool(FreeRDP_AutoDenyCertificate, FALSE);

    // Transport / pipeline throughput.
    setBool(FreeRDP_NetworkAutoDetect, TRUE);
    setBool(FreeRDP_SupportMultitransport, TRUE);
    setBool(FreeRDP_AsyncUpdate, TRUE);
    setBool(FreeRDP_AsyncChannels, TRUE);
    setBool(FreeRDP_FastPathOutput, TRUE);
    setBool(FreeRDP_FastPathInput, TRUE);
    setBool(FreeRDP_CompressionEnabled, TRUE);
    setU32(FreeRDP_FrameAcknowledge, 8);

    // Client-side rendering/cache hints.
    setBool(FreeRDP_BitmapCacheEnabled, TRUE);
    setBool(FreeRDP_BitmapCacheV3Enabled, TRUE);
    setBool(FreeRDP_SurfaceCommandsEnabled, TRUE);
    setBool(FreeRDP_FrameMarkerCommandEnabled, TRUE);
    setBool(FreeRDP_SurfaceFrameMarkerEnabled, TRUE);
    setBool(FreeRDP_MouseMotion, TRUE);
    setBool(FreeRDP_HasExtendedMouseEvent, TRUE);
    setBool(FreeRDP_HasHorizontalWheel, TRUE);

    // Keep rendering on classic GDI updates for this embedded framebuffer renderer.
    setBool(FreeRDP_SupportGraphicsPipeline, FALSE);
    setBool(FreeRDP_SurfaceCommandsEnabled, FALSE);
    setBool(FreeRDP_GfxProgressive, FALSE);
    setBool(FreeRDP_GfxProgressiveV2, FALSE);
    setBool(FreeRDP_GfxPlanar, FALSE);
    setBool(FreeRDP_GfxH264, FALSE);
    setBool(FreeRDP_GfxAVC444, FALSE);
    setBool(FreeRDP_GfxAVC444v2, FALSE);

    // Experience flags to reduce server-side effects.
    setBool(FreeRDP_DisableWallpaper, disableWallpaper);
    setBool(FreeRDP_DisableFullWindowDrag, disableFullWindowDrag);
    setBool(FreeRDP_DisableMenuAnims, disableMenuAnims);
    setBool(FreeRDP_DisableThemes, disableThemes);
    setBool(FreeRDP_AllowDesktopComposition, allowDesktopComposition);
    setBool(FreeRDP_AllowFontSmoothing, allowFontSmoothing);

    if (!settingsOk) {
      errorMessage = "Unable to configure FreeRDP settings.";
      freerdp_context_free(instance_.get());
      instance_.reset();
      return false;
    }

    registerInstanceOwner(instance_.get(), this);

    if (!freerdp_connect(instance_.get())) {
      errorMessage = "freerdp_connect failed.";
      unregisterInstanceOwner(instance_.get());
      freerdp_context_free(instance_.get());
      instance_.reset();
      return false;
    }
  running_.store(true);
  worker_ = std::thread([this]() { runLoop(); });
  connected_ = true;
  return true;
#else
  (void)host;
  (void)port;
  (void)username;
  (void)password;
  (void)domain;
  errorMessage =
    "FreeRDP headers/libraries are not available in this build. "
    "Build/link FreeRDP to enable real embedded desktop rendering.";
  return false;
#endif
  }

  void disconnect() {
    const bool wasRunning = running_.exchange(false);
    if (wasRunning && worker_.joinable()) {
      worker_.join();
    }

#if FRDP_HAS_FREERDP
    if (instance_) {
      freerdp_disconnect(instance_.get());
      unregisterInstanceOwner(instance_.get());
      freerdp_context_free(instance_.get());
      instance_.reset();
    }
#endif

    connected_ = false;
  }

  void setFrameCallback(FrameCallback callback) {
    std::lock_guard<std::mutex> lock(frameCallbackMutex_);
    frameCallback_ = std::move(callback);
  }

  void sendPointer(double x, double y, int buttons, double viewWidth, double viewHeight) {
    if (!connected_) {
      return;
    }

#if FRDP_HAS_FREERDP
    if (!instance_) return;
    auto* gdi = instance_->context != nullptr ? instance_->context->gdi : nullptr;
    auto* input = instance_->context->input;
    if (!input || !gdi || gdi->width <= 0 || gdi->height <= 0) return;

    const double safeViewWidth = viewWidth > 0.0 ? viewWidth : static_cast<double>(gdi->width);
    const double safeViewHeight = viewHeight > 0.0 ? viewHeight : static_cast<double>(gdi->height);

    const double scaledX = std::min(
      std::max(x * static_cast<double>(gdi->width) / safeViewWidth, 0.0),
      static_cast<double>(gdi->width - 1));
    const double scaledY = std::min(
      std::max(y * static_cast<double>(gdi->height) / safeViewHeight, 0.0),
      static_cast<double>(gdi->height - 1));

    const auto rdpX = static_cast<UINT16>(scaledX);
    const auto rdpY = static_cast<UINT16>(scaledY);
    lastPointerX_ = rdpX;
    lastPointerY_ = rdpY;

    // Detect button state changes (Flutter: bit0=left, bit1=right, bit2=middle).
    const int pressed  = buttons & ~lastButtons_;
    const int released = lastButtons_ & ~buttons;
    lastButtons_ = buttons;

    if (pressed  & 0x01) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON1 | PTR_FLAGS_DOWN, rdpX, rdpY);
    if (pressed  & 0x02) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON2 | PTR_FLAGS_DOWN, rdpX, rdpY);
    if (pressed  & 0x04) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON3 | PTR_FLAGS_DOWN, rdpX, rdpY);
    if (released & 0x01) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON1, rdpX, rdpY);
    if (released & 0x02) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON2, rdpX, rdpY);
    if (released & 0x04) freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON3, rdpX, rdpY);

    freerdp_input_send_mouse_event(input, PTR_FLAGS_MOVE, rdpX, rdpY);
#endif
  }

  void sendScroll(double deltaX, double deltaY) {
    if (!connected_) {
      return;
    }

#if FRDP_HAS_FREERDP
    if (!instance_) return;
    auto* gdi = instance_->context != nullptr ? instance_->context->gdi : nullptr;
    auto* input = instance_->context->input;
    if (!input || !gdi || gdi->width <= 0 || gdi->height <= 0) return;

    const UINT16 x = lastPointerX_;
    const UINT16 y = lastPointerY_;

    const auto sendWheel = [&](double delta, UINT16 wheelFlag, bool invertDirection) {
      if (delta == 0.0) return;

      const bool negative = invertDirection ? (delta > 0.0) : (delta < 0.0);
      UINT16 magnitude = static_cast<UINT16>(std::min(std::abs(delta), 255.0));
      UINT16 flags = wheelFlag | magnitude;
      if (negative) {
        flags |= PTR_FLAGS_WHEEL_NEGATIVE;
      }
      freerdp_input_send_mouse_event(input, flags, x, y);
    };

    // AppKit positive deltaY is scroll-up; RDP uses negative flag for down direction.
    sendWheel(deltaY, PTR_FLAGS_WHEEL, true);
    sendWheel(deltaX, PTR_FLAGS_HWHEEL, false);
#endif
  }

  void sendKey(int keyCode, bool isDown) {
    if (!connected_) {
      return;
    }

#if FRDP_HAS_FREERDP
    if (!instance_) return;
    auto* input = instance_->context->input;
    if (!input) return;

    // Flutter physicalKey.usbHidUsage encodes page in upper 16 bits.
    const int page  = (keyCode >> 16) & 0xFFFF;
    const int usage = keyCode & 0xFFFF;
    if (page != 0x0007) return; // keyboard / keypad page only

    struct ScancodeEntry { UINT8 scancode; bool extended; };

    // Modifier keys (HID 0xE0-0xE7)
    if (usage >= 0xE0 && usage <= 0xE7) {
      static const ScancodeEntry kMod[] = {
        {0x1D, false}, // E0 LCtrl
        {0x2A, false}, // E1 LShift
        {0x38, false}, // E2 LAlt
        {0x5B, true},  // E3 LMeta
        {0x1D, true},  // E4 RCtrl
        {0x36, false}, // E5 RShift
        {0x38, true},  // E6 RAlt
        {0x5C, true},  // E7 RMeta
      };
      const auto& e = kMod[usage - 0xE0];
      UINT16 flags = isDown ? 0 : KBD_FLAGS_RELEASE;
      if (e.extended) flags |= KBD_FLAGS_EXTENDED;
      freerdp_input_send_keyboard_event(input, flags, e.scancode);
      return;
    }

    // Main table: HID usage 0x04..0x64 -> PC/AT Set-1 scancode
    static const ScancodeEntry kTable[] = {
      {0x1E,false},{0x30,false},{0x2E,false},{0x20,false},{0x12,false},{0x21,false},{0x22,false},{0x23,false}, // 04-0B a-h
      {0x17,false},{0x24,false},{0x25,false},{0x26,false},{0x32,false},{0x31,false},{0x18,false},{0x19,false}, // 0C-13 i-p
      {0x10,false},{0x13,false},{0x1F,false},{0x14,false},{0x16,false},{0x2F,false},{0x11,false},{0x2D,false}, // 14-1B q-x
      {0x15,false},{0x2C,false}, // 1C-1D y z
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

    static const int kTableBase = 0x04;
    static const int kTableSize = static_cast<int>(sizeof(kTable) / sizeof(kTable[0]));
    if (usage < kTableBase || usage >= kTableBase + kTableSize) return;

    const auto& e = kTable[usage - kTableBase];
    if (e.scancode == 0) return;

    UINT16 flags = isDown ? 0 : KBD_FLAGS_RELEASE;
    if (e.extended) flags |= KBD_FLAGS_EXTENDED;
    freerdp_input_send_keyboard_event(input, flags, e.scancode);
#endif
  }

  void sendMacKey(int keyCode, bool isDown) {
    if (!connected_) {
      return;
    }

#if FRDP_HAS_FREERDP
    if (!instance_) return;
    auto* input = instance_->context->input;
    if (!input) return;

    UINT8 scancode = 0;
    bool extended = false;

    switch (keyCode) {
      case 0: scancode = 0x1E; break;   // A
      case 1: scancode = 0x1F; break;   // S
      case 2: scancode = 0x20; break;   // D
      case 3: scancode = 0x21; break;   // F
      case 4: scancode = 0x23; break;   // H
      case 5: scancode = 0x22; break;   // G
      case 6: scancode = 0x2C; break;   // Z
      case 7: scancode = 0x2D; break;   // X
      case 8: scancode = 0x2E; break;   // C
      case 9: scancode = 0x2F; break;   // V
      case 11: scancode = 0x30; break;  // B
      case 12: scancode = 0x10; break;  // Q
      case 13: scancode = 0x11; break;  // W
      case 14: scancode = 0x12; break;  // E
      case 15: scancode = 0x13; break;  // R
      case 16: scancode = 0x15; break;  // Y
      case 17: scancode = 0x14; break;  // T
      case 18: scancode = 0x02; break;  // 1
      case 19: scancode = 0x03; break;  // 2
      case 20: scancode = 0x04; break;  // 3
      case 21: scancode = 0x05; break;  // 4
      case 22: scancode = 0x07; break;  // 6
      case 23: scancode = 0x06; break;  // 5
      case 24: scancode = 0x0D; break;  // =
      case 25: scancode = 0x0A; break;  // 9
      case 26: scancode = 0x08; break;  // 7
      case 27: scancode = 0x0C; break;  // -
      case 28: scancode = 0x09; break;  // 8
      case 29: scancode = 0x0B; break;  // 0
      case 30: scancode = 0x1B; break;  // ]
      case 31: scancode = 0x18; break;  // O
      case 32: scancode = 0x16; break;  // U
      case 33: scancode = 0x1A; break;  // [
      case 34: scancode = 0x17; break;  // I
      case 35: scancode = 0x19; break;  // P
      case 36: scancode = 0x1C; break;  // Return
      case 37: scancode = 0x26; break;  // L
      case 38: scancode = 0x24; break;  // J
      case 39: scancode = 0x28; break;  // '
      case 40: scancode = 0x25; break;  // K
      case 41: scancode = 0x27; break;  // ;
      case 42: scancode = 0x2B; break;  // \
      case 43: scancode = 0x33; break;  // ,
      case 44: scancode = 0x35; break;  // /
      case 45: scancode = 0x31; break;  // N
      case 46: scancode = 0x32; break;  // M
      case 47: scancode = 0x34; break;  // .
      case 48: scancode = 0x0F; break;  // Tab
      case 49: scancode = 0x39; break;  // Space
      case 50: scancode = 0x29; break;  // `
      case 51: scancode = 0x0E; break;  // Backspace
      case 53: scancode = 0x01; break;  // Escape
      case 55: scancode = 0x5B; extended = true; break; // Left Command
      case 56: scancode = 0x2A; break;  // Left Shift
      case 57: scancode = 0x3A; break;  // CapsLock
      case 58: scancode = 0x38; break;  // Left Option
      case 59: scancode = 0x1D; break;  // Left Control
      case 60: scancode = 0x36; break;  // Right Shift
      case 61: scancode = 0x38; extended = true; break; // Right Option
      case 62: scancode = 0x1D; extended = true; break; // Right Control
      case 65: scancode = 0x53; break;  // Keypad .
      case 67: scancode = 0x37; break;  // Keypad *
      case 69: scancode = 0x4E; break;  // Keypad +
      case 71: scancode = 0x45; break;  // Keypad Clear / NumLock
      case 75: scancode = 0x35; extended = true; break; // Keypad /
      case 76: scancode = 0x1C; extended = true; break; // Keypad Enter
      case 78: scancode = 0x4A; break;  // Keypad -
      case 81: scancode = 0x0D; break;  // Keypad =
      case 82: scancode = 0x52; break;  // Keypad 0
      case 83: scancode = 0x4F; break;  // Keypad 1
      case 84: scancode = 0x50; break;  // Keypad 2
      case 85: scancode = 0x51; break;  // Keypad 3
      case 86: scancode = 0x4B; break;  // Keypad 4
      case 87: scancode = 0x4C; break;  // Keypad 5
      case 88: scancode = 0x4D; break;  // Keypad 6
      case 89: scancode = 0x47; break;  // Keypad 7
      case 91: scancode = 0x48; break;  // Keypad 8
      case 92: scancode = 0x49; break;  // Keypad 9
      case 96: scancode = 0x3F; break;  // F5
      case 97: scancode = 0x40; break;  // F6
      case 98: scancode = 0x41; break;  // F7
      case 99: scancode = 0x3D; break;  // F3
      case 100: scancode = 0x42; break; // F8
      case 101: scancode = 0x43; break; // F9
      case 103: scancode = 0x57; break; // F11
      case 109: scancode = 0x44; break; // F10
      case 111: scancode = 0x58; break; // F12
      case 114: scancode = 0x52; extended = true; break; // Help/Insert
      case 115: scancode = 0x47; extended = true; break; // Home
      case 116: scancode = 0x49; extended = true; break; // PageUp
      case 117: scancode = 0x53; extended = true; break; // Forward Delete
      case 118: scancode = 0x3E; break; // F4
      case 119: scancode = 0x4F; extended = true; break; // End
      case 120: scancode = 0x3C; break; // F2
      case 121: scancode = 0x51; extended = true; break; // PageDown
      case 122: scancode = 0x3B; break; // F1
      case 123: scancode = 0x4B; extended = true; break; // Left
      case 124: scancode = 0x4D; extended = true; break; // Right
      case 125: scancode = 0x50; extended = true; break; // Down
      case 126: scancode = 0x48; extended = true; break; // Up
      default: return;
    }

    UINT16 flags = isDown ? 0 : KBD_FLAGS_RELEASE;
    if (extended) flags |= KBD_FLAGS_EXTENDED;
    freerdp_input_send_keyboard_event(input, flags, scancode);
#endif
  }

  bool connected() const { return connected_; }

 private:
  static bool normalizeHost(std::string& host, std::string& errorMessage) {
    auto trim = [](std::string& value) {
      const auto isSpace = [](unsigned char c) { return std::isspace(c) != 0; };
      while (!value.empty() && isSpace(static_cast<unsigned char>(value.front()))) {
        value.erase(value.begin());
      }
      while (!value.empty() && isSpace(static_cast<unsigned char>(value.back()))) {
        value.pop_back();
      }
    };

    trim(host);
    if (host.empty()) {
      errorMessage = "Host is empty.";
      return false;
    }

    const std::string rdpPrefix = "rdp://";
    if (host.rfind(rdpPrefix, 0) == 0) {
      host = host.substr(rdpPrefix.size());
      trim(host);
    }

    // If user entered host:port while port is provided separately, strip the suffix.
    const auto colonPos = host.rfind(':');
    const bool hasSingleColon = (colonPos != std::string::npos) &&
                                (host.find(':') == colonPos) &&
                                (host.find(']') == std::string::npos);
    if (hasSingleColon) {
      const std::string maybePort = host.substr(colonPos + 1);
      if (!maybePort.empty() &&
          std::all_of(maybePort.begin(), maybePort.end(), [](unsigned char c) { return std::isdigit(c) != 0; })) {
        host = host.substr(0, colonPos);
        trim(host);
      }
    }

    if (host.empty()) {
      errorMessage = "Host is invalid after normalization.";
      return false;
    }

    return true;
  }

  static bool validateHostResolvable(const std::string& host, int port, std::string& errorMessage) {
    struct addrinfo hints {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo* result = nullptr;
    const std::string service = std::to_string(port);
    const int rc = getaddrinfo(host.c_str(), service.c_str(), &hints, &result);
    if (rc != 0) {
      errorMessage = "Host resolution failed for '" + host + "': " + gai_strerror(rc);
      return false;
    }

    freeaddrinfo(result);
    return true;
  }

  void runLoop() {
    while (running_.load()) {
#if FRDP_HAS_FREERDP
      if (instance_ != nullptr) {
        if (!freerdp_check_fds(instance_.get())) {
          running_.store(false);
          break;
        }
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(16));
#else
      std::this_thread::sleep_for(std::chrono::milliseconds(16));
#endif
    }
  }

#if FRDP_HAS_FREERDP
  static void registerInstanceOwner(freerdp* instance, FrdpEngineCore* owner) {
    std::lock_guard<std::mutex> lock(instanceOwnerMutex());
    instanceOwnerMap()[instance] = owner;
  }

  static void unregisterInstanceOwner(freerdp* instance) {
    std::lock_guard<std::mutex> lock(instanceOwnerMutex());
    instanceOwnerMap().erase(instance);
  }

  static FrdpEngineCore* lookupInstanceOwner(freerdp* instance) {
    std::lock_guard<std::mutex> lock(instanceOwnerMutex());
    const auto it = instanceOwnerMap().find(instance);
    if (it == instanceOwnerMap().end()) {
      return nullptr;
    }
    return it->second;
  }

  static std::unordered_map<freerdp*, FrdpEngineCore*>& instanceOwnerMap() {
    static std::unordered_map<freerdp*, FrdpEngineCore*> map;
    return map;
  }

  static std::mutex& instanceOwnerMutex() {
    static std::mutex mutex;
    return mutex;
  }

  static BOOL onPreConnect(freerdp* instance) {
    if (instance == nullptr || instance->context == nullptr) {
      return FALSE;
    }

    // Channel addins like rdpdr are optional for basic desktop rendering.
    // In embedded mode we continue even if dynamic addin loading is unavailable.
    (void)freerdp_client_load_addins(instance->context->channels, instance->context->settings);
    return TRUE;
  }

  static BOOL onPostConnect(freerdp* instance) {
    if (instance == nullptr || instance->context == nullptr) {
      return FALSE;
    }

    if (!gdi_init(instance, PIXEL_FORMAT_BGRA32)) {
      return FALSE;
    }

    if (instance->context->update != nullptr) {
      instance->context->update->BeginPaint = &FrdpEngineCore::onBeginPaint;
      instance->context->update->EndPaint = &FrdpEngineCore::onEndPaint;
    }

    return TRUE;
  }

  static BOOL onBeginPaint(rdpContext* context) {
    (void)context;
    return TRUE;
  }

  static BOOL onEndPaint(rdpContext* context) {
    if (context == nullptr || context->instance == nullptr) {
      return TRUE;
    }

    auto* core = lookupInstanceOwner(context->instance);
    if (core == nullptr) {
      return TRUE;
    }

    core->emitFrameFromFreeRdp();
    return TRUE;
  }

  bool emitFrameFromFreeRdp() {
    if (instance_ == nullptr || instance_->context == nullptr || instance_->context->gdi == nullptr) {
      return false;
    }

    rdpGdi* gdi = instance_->context->gdi;
    if (gdi->primary_buffer == nullptr || gdi->width <= 0 || gdi->height <= 0 || gdi->stride <= 0) {
      return false;
    }

    FrameCallback callback;
    {
      std::lock_guard<std::mutex> lock(frameCallbackMutex_);
      callback = frameCallback_;
    }

    if (!callback) {
      return false;
    }

    callback(gdi->primary_buffer, gdi->width, gdi->height, gdi->stride);
    return true;
  }

  struct FreeRdpDeleter {
    void operator()(freerdp* instance) const {
      if (instance != nullptr) {
        if (instance->context != nullptr && instance->context->gdi != nullptr) {
          gdi_free(instance);
        }
        if (instance->context != nullptr) {
          freerdp_context_free(instance);
        }
        freerdp_free(instance);
      }
    }
  };
  std::unique_ptr<freerdp, FreeRdpDeleter> instance_;
#endif

  std::thread worker_;
  std::atomic<bool> running_{false};
  std::mutex frameCallbackMutex_;
  FrameCallback frameCallback_;
  bool connected_ = false;
  int lastButtons_ = 0;
  UINT16 lastPointerX_ = 0;
  UINT16 lastPointerY_ = 0;
};

@interface FrdpRdpEngineAdapter ()
@property(nonatomic, strong) NSView *renderView;
@property(nonatomic, assign, getter=isConnected) BOOL connected;
@end

@implementation FrdpRdpEngineAdapter {
  std::unique_ptr<FrdpEngineCore> _core;
  NSTextField *_statusLabel;
  FrdpFrameView *_frameView;
  std::atomic<bool> _frameUpdatePending;
  dispatch_queue_t _frameProcessingQueue;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _frameUpdatePending.store(false);
    _frameProcessingQueue = dispatch_queue_create("com.frdp.frame-processing", DISPATCH_QUEUE_SERIAL);
    _core = std::make_unique<FrdpEngineCore>();
    _renderView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 640, 360)];
    _renderView.wantsLayer = YES;
    _renderView.layer.backgroundColor = NSColor.blackColor.CGColor;

    _frameView = [[FrdpFrameView alloc] init];
    _frameView.translatesAutoresizingMaskIntoConstraints = NO;
    [_renderView addSubview:_frameView];

    _statusLabel = [NSTextField labelWithString:@"RDP engine idle"]; 
    _statusLabel.textColor = NSColor.whiteColor;
    _statusLabel.backgroundColor = [NSColor colorWithWhite:0 alpha:0.45];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_renderView addSubview:_statusLabel];

    [NSLayoutConstraint activateConstraints:@[
      [_frameView.leadingAnchor constraintEqualToAnchor:_renderView.leadingAnchor],
      [_frameView.trailingAnchor constraintEqualToAnchor:_renderView.trailingAnchor],
      [_frameView.topAnchor constraintEqualToAnchor:_renderView.topAnchor],
      [_frameView.bottomAnchor constraintEqualToAnchor:_renderView.bottomAnchor],
      [_statusLabel.leadingAnchor constraintEqualToAnchor:_renderView.leadingAnchor constant:12],
      [_statusLabel.topAnchor constraintEqualToAnchor:_renderView.topAnchor constant:12],
    ]];

    __weak FrdpRdpEngineAdapter* weakSelf = self;
    _core->setFrameCallback([weakSelf](const uint8_t* data, int width, int height, int stride) {
      FrdpRdpEngineAdapter* strongSelf = weakSelf;
      if (strongSelf == nil || data == nullptr || width <= 0 || height <= 0 || stride <= 0) {
        return;
      }

      bool expected = false;
      if (!strongSelf->_frameUpdatePending.compare_exchange_strong(expected, true)) {
        return;
      }

      const size_t bytesPerRow = static_cast<size_t>(stride);
      const size_t frameBytes = bytesPerRow * static_cast<size_t>(height);
      uint8_t* copied = static_cast<uint8_t*>(malloc(frameBytes));
      if (copied == nullptr) {
        strongSelf->_frameUpdatePending.store(false);
        return;
      }
      memcpy(copied, data, frameBytes);

      dispatch_async(strongSelf->_frameProcessingQueue, ^{
        CGDataProviderRef provider = CGDataProviderCreateWithData(nullptr, copied, frameBytes, FrdpReleaseFrameBuffer);
        if (provider == nullptr) {
          strongSelf->_frameUpdatePending.store(false);
          return;
        }

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        CGImageRef image = CGImageCreate(
            static_cast<size_t>(width),
            static_cast<size_t>(height),
            8,
            32,
            bytesPerRow,
            colorSpace,
            bitmapInfo,
            provider,
            nullptr,
            false,
            kCGRenderingIntentDefault);

        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);

        if (image == nullptr) {
          strongSelf->_frameUpdatePending.store(false);
          return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
          FrdpRdpEngineAdapter* innerSelf = weakSelf;
          if (innerSelf != nil) {
            [innerSelf->_frameView updateImage:image];
            innerSelf->_frameUpdatePending.store(false);
            CGImageRelease(image);
            return;
          }

          strongSelf->_frameUpdatePending.store(false);
          CGImageRelease(image);
        });
      });
    });
  }
  return self;
}

- (BOOL)connectWithHost:(NSString *)host
                   port:(NSInteger)port
               username:(NSString *)username
               password:(NSString *)password
                 domain:(nullable NSString *)domain
      ignoreCertificate:(BOOL)ignoreCertificate
      performanceProfile:(NSString *)performanceProfile
                  error:(NSError *__autoreleasing _Nullable *)error {
  std::string errorMessage;
  const bool ok = _core->connect(
      host.UTF8String,
      static_cast<int>(port),
      username.UTF8String,
      password.UTF8String,
      domain != nil ? domain.UTF8String : "",
      ignoreCertificate == YES,
      performanceProfile.UTF8String,
      errorMessage);

  self.connected = ok;
  if (ok) {
    _statusLabel.stringValue = [NSString stringWithFormat:@"Embedded RDP connected: %@:%ld", host,
                                                          (long)port];
    return YES;
  }

  _statusLabel.stringValue = @"Embedded RDP unavailable";
  if (error != nullptr) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @(errorMessage.c_str())};
    *error = [NSError errorWithDomain:@"frdp.engine"
                                 code:1001
                             userInfo:userInfo];
  }
  return NO;
}

- (void)disconnect {
  _core->disconnect();
  self.connected = NO;
  _statusLabel.stringValue = @"RDP engine disconnected";
}

- (void)sendPointerEventWithX:(double)x y:(double)y buttons:(NSInteger)buttons {
  _core->sendPointer(x, y, static_cast<int>(buttons), _renderView.bounds.size.width, _renderView.bounds.size.height);
}

- (void)sendPointerEventWithX:(double)x
                           y:(double)y
                     buttons:(NSInteger)buttons
                    viewWidth:(double)viewWidth
                   viewHeight:(double)viewHeight {
  _core->sendPointer(x, y, static_cast<int>(buttons), viewWidth, viewHeight);
}

- (void)sendScrollEventWithDeltaX:(double)deltaX deltaY:(double)deltaY {
  _core->sendScroll(deltaX, deltaY);
}

- (void)sendKeyEventWithKeyCode:(NSInteger)keyCode isDown:(BOOL)isDown {
  _core->sendKey(static_cast<int>(keyCode), isDown);
}

- (void)sendMacKeyEventWithKeyCode:(NSInteger)keyCode isDown:(BOOL)isDown {
  _core->sendMacKey(static_cast<int>(keyCode), isDown);
}

@end
