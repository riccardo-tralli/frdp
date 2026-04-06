#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <netdb.h>
#include <string>
#include <thread>
#include <unordered_map>
#include "FrdpFreeRdpSettingsApplier.hpp"

#if __has_include(<freerdp/freerdp.h>)
#define FRDP_HAS_FREERDP 1
#include <freerdp/client.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/client/channels.h>
#include <freerdp/addin.h>
#include <freerdp/channels/channels.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/gdi/gfx.h>
#include <freerdp/client/rdpgfx.h>
#include <freerdp/event.h>
#include <winpr/synch.h>
#else
#define FRDP_HAS_FREERDP 0
#endif

// ---------------------------------------------------------------------------
// FrdpEngineCore
//
// Pure C++ core that owns the FreeRDP lifecycle, the I/O worker thread, and
// all input-forwarding calls.  Thread-safety contract:
//   - connect() / disconnect() must be called from the main thread.
//   - send*() may be called from any thread; they take stateMutex_ internally.
//   - The frame callback is invoked from the worker thread.
// ---------------------------------------------------------------------------
class FrdpEngineCore {
 public:
  // Callback: (pixelData, width, height, stride).  Called from the worker
  // thread with no lock held; the callee must copy the data if it needs to
  // outlive the call.
  using FrameCallback = std::function<void(const uint8_t*, int, int, int)>;
  using ConnectionStateCallback = std::function<void(bool)>;

  FrdpEngineCore() = default;
  ~FrdpEngineCore() { disconnect(); }

  // Non-copyable, non-movable (owns a thread and mutexes).
  FrdpEngineCore(const FrdpEngineCore&) = delete;
  FrdpEngineCore& operator=(const FrdpEngineCore&) = delete;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  bool connect(const FrdpFreeRdpConnectConfig& config, std::string& errorMessage);

  void disconnect();

  bool connected() const { return connected_.load(); }

  // -------------------------------------------------------------------------
  // Frame
  // -------------------------------------------------------------------------

  void setFrameCallback(FrameCallback callback) {
    std::lock_guard<std::mutex> lock(frameCallbackMutex_);
    frameCallback_ = std::move(callback);
  }

  void setConnectionStateCallback(ConnectionStateCallback callback) {
    std::lock_guard<std::mutex> lock(connectionCallbackMutex_);
    connectionStateCallback_ = std::move(callback);
  }

  // -------------------------------------------------------------------------
  // Input
  // -------------------------------------------------------------------------

  void sendPointer(double x, double y, int buttons, double viewWidth, double viewHeight);
  void sendScroll(double deltaX, double deltaY);

  // Flutter physicalKey.usbHidUsage encoding (page << 16 | usage).
  void sendKey(int keyCode, bool isDown);

  // macOS virtual keycode (NSEvent.keyCode) encoding.
  void sendMacKey(int keyCode, bool isDown);

 private:
  // -------------------------------------------------------------------------
  // Host validation helpers
  // -------------------------------------------------------------------------

  static bool normalizeHost(std::string& host, std::string& errorMessage);
  static bool validateHostResolvable(const std::string& host, int port, std::string& errorMessage);

  // -------------------------------------------------------------------------
  // Worker loop
  // -------------------------------------------------------------------------

  void runLoop();
  void notifyConnectionStateChange(bool connected);

  // -------------------------------------------------------------------------
  // FreeRDP instance registry (static, process-wide)
  // -------------------------------------------------------------------------

#if FRDP_HAS_FREERDP
  static void registerInstanceOwner(freerdp* instance, FrdpEngineCore* owner);
  static void unregisterInstanceOwner(freerdp* instance);
  static FrdpEngineCore* lookupInstanceOwner(freerdp* instance);

  static std::unordered_map<freerdp*, FrdpEngineCore*>& instanceOwnerMap();
  static std::mutex& instanceOwnerMutex();

  // FreeRDP callbacks
  static BOOL onPreConnect(freerdp* instance);
  static BOOL onPostConnect(freerdp* instance);
  static BOOL onBeginPaint(rdpContext* context);
  static BOOL onEndPaint(rdpContext* context);

  static void onChannelConnected(void* context, const ChannelConnectedEventArgs* e);
  static void onChannelDisconnected(void* context, const ChannelDisconnectedEventArgs* e);

  void emitFrameFromFreeRdp();

  // Custom deleter: frees GDI, context, and the freerdp instance in order.
  struct FreeRdpDeleter {
    void operator()(freerdp* instance) const;
  };

  std::unique_ptr<freerdp, FreeRdpDeleter> instance_;
#endif

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  std::thread            worker_;
  std::atomic<bool>      running_{false};
  std::atomic<bool>      connected_{false};
  std::mutex             stateMutex_;
  std::mutex             frameCallbackMutex_;
  FrameCallback          frameCallback_;
  std::mutex             connectionCallbackMutex_;
  ConnectionStateCallback connectionStateCallback_;
  int                    lastButtons_{0};
  uint16_t               lastPointerX_{0};
  uint16_t               lastPointerY_{0};
};
