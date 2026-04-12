#pragma once

#include <functional>
#include <mutex>
#include <string>

#if __has_include(<freerdp/freerdp.h>)
#define FRDP_HAS_CLIPRDR 1
#include <freerdp/client/cliprdr.h>
#else
#define FRDP_HAS_CLIPRDR 0
#endif

// ---------------------------------------------------------------------------
// FrdpClipboardManager
//
// Manages the FreeRDP clipboard-redirect (cliprdr) virtual channel.
//
// Direction: Mac → RDP
//   The macOS clipboard monitor detects NSPasteboard changes and calls
//   onLocalClipboardChanged().  The manager announces the format to the
//   server; when the server later requests the data the manager supplies it.
//
// Direction: RDP → Mac
//   The server sends a ServerFormatList event; the manager requests
//   CF_UNICODETEXT data and, once received, fires textReceivedCallback_.
//   The adapter dispatches to the main thread and writes NSPasteboard.
//
// Thread-safety:
//   initialize() / onChannelConnected path — called from main thread.
//   FreeRDP callbacks — called from the FreeRDP worker thread.
//   onLocalClipboardChanged() — called from main thread.
//   All shared state is guarded by mutex_.
// ---------------------------------------------------------------------------
class FrdpClipboardManager {
 public:
  using TextReceivedCallback = std::function<void(const std::string& utf8Text)>;

  FrdpClipboardManager() = default;
  ~FrdpClipboardManager() { uninitialize(); }

  FrdpClipboardManager(const FrdpClipboardManager&)            = delete;
  FrdpClipboardManager& operator=(const FrdpClipboardManager&) = delete;

#if FRDP_HAS_CLIPRDR
  // Called when the cliprdr channel connects (from FrdpEngineCore::onChannelConnected).
  bool initialize(CliprdrClientContext* context);
#endif

  // Called when the cliprdr channel disconnects or the session is torn down.
  void uninitialize();

  // Called by the macOS NSPasteboard monitor when local clipboard text changes.
  // Safe to call from the main thread at any time.
  void onLocalClipboardChanged(const std::string& utf8Text);

  // Register a callback fired on the FreeRDP worker thread when the remote
  // host has placed new text on the clipboard.  The callee is responsible
  // for dispatching to the main thread before touching UI / NSPasteboard.
  void setTextReceivedCallback(TextReceivedCallback cb) {
    std::lock_guard<std::mutex> lock(mutex_);
    textReceivedCallback_ = std::move(cb);
  }

 private:
#if FRDP_HAS_CLIPRDR
  // Retrieve the owning FrdpClipboardManager from the context's custom field.
  static FrdpClipboardManager* fromContext(CliprdrClientContext* ctx);

  // Send CLIPRDR general capabilities to the remote peer.
  static UINT sendClientCapabilities(CliprdrClientContext* context);

  // --------------------------------------------------------------------------
  // cliprdr server→client callbacks (assigned in initialize()).
  // --------------------------------------------------------------------------
  static UINT onServerCapabilities(CliprdrClientContext* context,
                                    const CLIPRDR_CAPABILITIES* capabilities);
  static UINT onMonitorReady(CliprdrClientContext* context,
                              const CLIPRDR_MONITOR_READY* monitorReady);
  static UINT onServerFormatList(CliprdrClientContext* context,
                                  const CLIPRDR_FORMAT_LIST* formatList);
  static UINT onServerFormatListResponse(
      CliprdrClientContext* context,
      const CLIPRDR_FORMAT_LIST_RESPONSE* response);
  static UINT onServerFormatDataRequest(
      CliprdrClientContext* context,
      const CLIPRDR_FORMAT_DATA_REQUEST* request);
  static UINT onServerFormatDataResponse(
      CliprdrClientContext* context,
      const CLIPRDR_FORMAT_DATA_RESPONSE* response);

  // Send our format list to the server (must be called with mutex_ held).
  bool sendLocalFormatList();

  CliprdrClientContext* context_ = nullptr;
#endif

  std::mutex           mutex_;
  std::string          pendingLocalText_;
  bool                 hasPendingText_      = false;
  bool                 serverReady_         = false;
  TextReceivedCallback textReceivedCallback_;
};
