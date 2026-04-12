#include "FrdpEngineCore.hpp"
#include "FrdpFreeRdpSettingsApplier.hpp"
#include "FrdpInputMapper.hpp"
#include "../clipboard/FrdpClipboardManager.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <chrono>
#include <future>

namespace {

using Clock = std::chrono::steady_clock;

struct DnsCacheEntry {
  Clock::time_point resolvedAt;
};

std::mutex& dnsCacheMutex() {
  static std::mutex mutex;
  return mutex;
}

std::unordered_map<std::string, DnsCacheEntry>& dnsCache() {
  static std::unordered_map<std::string, DnsCacheEntry> cache;
  return cache;
}

std::string dnsCacheKey(const std::string& host, int port) {
  return host + ":" + std::to_string(port);
}

} // namespace

// ---------------------------------------------------------------------------
// FrdpEngineCore — implementation
// ---------------------------------------------------------------------------

// MARK: - Host validation ---------------------------------------------------

bool FrdpEngineCore::normalizeHost(std::string& host, std::string& errorMessage) {
  auto trim = [](std::string& s) {
    const auto issp = [](unsigned char c) { return std::isspace(c) != 0; };
    while (!s.empty() && issp(static_cast<unsigned char>(s.front()))) s.erase(s.begin());
    while (!s.empty() && issp(static_cast<unsigned char>(s.back())))  s.pop_back();
  };

  trim(host);
  if (host.empty()) { errorMessage = "Host is empty."; return false; }

  // Strip optional rdp:// scheme.
  const std::string prefix = "rdp://";
  if (host.rfind(prefix, 0) == 0) { host = host.substr(prefix.size()); trim(host); }

  // Strip embedded :port suffix when port is passed separately.
  const auto colonPos = host.rfind(':');
  const bool hasSingleColon =
      colonPos != std::string::npos &&
      host.find(':') == colonPos &&
      host.find(']') == std::string::npos; // exclude IPv6 literals
  if (hasSingleColon) {
    const std::string maybePort = host.substr(colonPos + 1);
    if (!maybePort.empty() &&
        std::all_of(maybePort.begin(), maybePort.end(),
                    [](unsigned char c) { return std::isdigit(c) != 0; })) {
      host = host.substr(0, colonPos);
      trim(host);
    }
  }

  if (host.empty()) { errorMessage = "Host is invalid after normalization."; return false; }
  return true;
}

bool FrdpEngineCore::validateHostResolvable(const std::string& host,
                                             int port,
                                             std::string& errorMessage) {
  constexpr auto kDnsCacheTtl = std::chrono::seconds(30);
  constexpr auto kDnsResolveTimeout = std::chrono::seconds(2);

  const auto now = Clock::now();
  const std::string cacheKey = dnsCacheKey(host, port);

  {
    std::lock_guard<std::mutex> lock(dnsCacheMutex());
    auto it = dnsCache().find(cacheKey);
    if (it != dnsCache().end() && (now - it->second.resolvedAt) < kDnsCacheTtl) {
      return true;
    }
    if (it != dnsCache().end() && (now - it->second.resolvedAt) >= kDnsCacheTtl) {
      dnsCache().erase(it);
    }
  }

  std::promise<std::pair<bool, std::string>> resolvePromise;
  auto resolveFuture = resolvePromise.get_future();

  std::thread resolver([host, port, promise = std::move(resolvePromise)]() mutable {
    struct addrinfo hints {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo* result = nullptr;
    const std::string service = std::to_string(port);
    const int rc = getaddrinfo(host.c_str(), service.c_str(), &hints, &result);
    if (rc != 0) {
      promise.set_value({false, "Host resolution failed for '" + host + "': " + gai_strerror(rc)});
      return;
    }

    freeaddrinfo(result);
    promise.set_value({true, ""});
  });

  const auto status = resolveFuture.wait_for(kDnsResolveTimeout);
  if (status != std::future_status::ready) {
    resolver.detach();
    errorMessage = "Host resolution timed out for '" + host + "'.";
    return false;
  }

  resolver.join();

  auto [ok, message] = resolveFuture.get();
  if (!ok) {
    errorMessage = std::move(message);
    return false;
  }

  {
    std::lock_guard<std::mutex> lock(dnsCacheMutex());
    dnsCache()[cacheKey] = DnsCacheEntry{now};
  }

  return true;
}

// MARK: - Lifecycle ---------------------------------------------------------

bool FrdpEngineCore::connect(const FrdpFreeRdpConnectConfig& config,
                              std::string& errorMessage) {
  // Host validation runs before state lock acquisition. DNS resolution has
  // a bounded timeout and short-lived cache to avoid repeated long stalls.
  std::string normalizedHost = config.host;
  if (!normalizeHost(normalizedHost, errorMessage)) return false;
  if (!validateHostResolvable(normalizedHost, config.port, errorMessage)) return false;

  std::lock_guard<std::mutex> stateLock(stateMutex_);

  if (running_.load()) {
    errorMessage = "RDP session is already running.";
    return false;
  }

  connected_.store(false);
  lastButtons_  = 0;
  lastPointerX_ = 0;
  lastPointerY_ = 0;

#if FRDP_HAS_FREERDP
  const bool clipboardEnabled = config.enableClipboard;
  if (clipboardEnabled) {
    clipboardManager_ = std::make_unique<FrdpClipboardManager>();
    clipboardManager_->setTextReceivedCallback([this](const std::string& utf8Text) {
      ClipboardCallback cb;
      {
        std::lock_guard<std::mutex> lock(clipboardCallbackMutex_);
        cb = clipboardCallback_;
      }
      if (cb) cb(utf8Text);
    });
  } else {
    clipboardManager_.reset();
  }

  instance_.reset(freerdp_new());
  if (!instance_) { errorMessage = "Unable to allocate FreeRDP instance."; return false; }

  instance_->PreConnect = &FrdpEngineCore::onPreConnect;
  instance_->PostConnect = &FrdpEngineCore::onPostConnect;
  instance_->LoadChannels = clipboardEnabled ? &FrdpEngineCore::onLoadChannels : nullptr;

  if (!freerdp_context_new(instance_.get())) {
    errorMessage = "Unable to allocate FreeRDP context.";
    instance_.reset();
    return false;
  }

  auto* settings = (instance_->context != nullptr) ? instance_->context->settings : nullptr;
  if (!settings) {
    errorMessage = "FreeRDP settings are not initialized.";
    instance_.reset();
    return false;
  }

  FrdpFreeRdpConnectConfig resolvedConfig = config;
  resolvedConfig.host = normalizedHost;

  const bool ok = FrdpApplyFreeRdpSettings(settings, resolvedConfig);

  if (!ok) {
    errorMessage = "Unable to configure FreeRDP settings.";
    instance_.reset();
    return false;
  }

  registerInstanceOwner(instance_.get(), this);

  if (!freerdp_connect(instance_.get())) {
    errorMessage = "freerdp_connect failed.";
    unregisterInstanceOwner(instance_.get());
    instance_.reset();
    return false;
  }

  running_.store(true);
  worker_ = std::thread([this]() { runLoop(); });
  connected_.store(true);
  notifyConnectionStateChange(true);
  return true;

#else
  (void)config;
  errorMessage = "FreeRDP headers/libraries are not available in this build. "
                 "Build/link FreeRDP to enable real embedded desktop rendering.";
  return false;
#endif
}

void FrdpEngineCore::disconnect() {
  const bool wasConnected = connected_.load();
  running_.store(false);

  // Wake the worker's WaitForMultipleObjects before joining, otherwise
  // the thread blocks indefinitely waiting for the next network event.
#if FRDP_HAS_FREERDP
  {
    std::lock_guard<std::mutex> stateLock(stateMutex_);
    if (instance_) freerdp_abort_connect_context(instance_->context);
  }
#endif

  if (worker_.joinable()) worker_.join();

  {
    std::lock_guard<std::mutex> stateLock(stateMutex_);
#if FRDP_HAS_FREERDP
    if (instance_) {
      freerdp_disconnect(instance_.get());
      unregisterInstanceOwner(instance_.get());
      instance_.reset();
    }
    if (clipboardManager_) {
      clipboardManager_->uninitialize();
    }
#endif
    connected_.store(false);
    lastButtons_  = 0;
    lastPointerX_ = 0;
    lastPointerY_ = 0;
  }

  if (wasConnected) notifyConnectionStateChange(false);
}

// MARK: - Input -------------------------------------------------------------

void FrdpEngineCore::sendPointer(double x, double y, int buttons,
                                  double viewWidth, double viewHeight) {
  if (!connected_.load()) return;

#if FRDP_HAS_FREERDP
  std::lock_guard<std::mutex> lock(stateMutex_);
  if (!instance_) return;
  auto* gdi   = instance_->context ? instance_->context->gdi   : nullptr;
  auto* input = instance_->context ? instance_->context->input : nullptr;
  if (!input || !gdi || gdi->width <= 0 || gdi->height <= 0) return;

  const double safeW = viewWidth  > 0.0 ? viewWidth  : static_cast<double>(gdi->width);
  const double safeH = viewHeight > 0.0 ? viewHeight : static_cast<double>(gdi->height);

  const auto rdpX = static_cast<UINT16>(
      std::min(std::max(x * gdi->width / safeW, 0.0), static_cast<double>(gdi->width  - 1)));
  const auto rdpY = static_cast<UINT16>(
      std::min(std::max(y * gdi->height / safeH, 0.0), static_cast<double>(gdi->height - 1)));

  lastPointerX_ = rdpX;
  lastPointerY_ = rdpY;

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

void FrdpEngineCore::sendScroll(double deltaX, double deltaY) {
  if (!connected_.load()) return;

#if FRDP_HAS_FREERDP
  std::lock_guard<std::mutex> lock(stateMutex_);
  if (!instance_) return;
  auto* input = instance_->context ? instance_->context->input : nullptr;
  if (!input) return;

  const UINT16 x = lastPointerX_, y = lastPointerY_;

  const auto sendWheel = [&](double delta, UINT16 flag, bool invert) {
    if (delta == 0.0) return;
    const bool negative = invert ? (delta > 0.0) : (delta < 0.0);
    UINT16 magnitude    = static_cast<UINT16>(std::min(std::abs(delta), 255.0));
    UINT16 flags        = flag | magnitude;
    if (negative) flags |= PTR_FLAGS_WHEEL_NEGATIVE;
    freerdp_input_send_mouse_event(input, flags, x, y);
  };

  // AppKit positive deltaY is scroll-up; RDP uses the NEGATIVE flag for down.
  sendWheel(deltaY, PTR_FLAGS_WHEEL,  true);
  sendWheel(deltaX, PTR_FLAGS_HWHEEL, false);
#endif
}

void FrdpEngineCore::sendKey(int keyCode, bool isDown) {
  if (!connected_.load()) return;

#if FRDP_HAS_FREERDP
  std::lock_guard<std::mutex> lock(stateMutex_);
  if (!instance_) return;
  auto* input = instance_->context ? instance_->context->input : nullptr;
  if (!input) return;

  const FrdpScancode sc = FrdpHidUsageToScancode(keyCode);
  if (sc.scancode == 0) return;

  UINT16 flags = isDown ? 0 : KBD_FLAGS_RELEASE;
  if (sc.extended) flags |= KBD_FLAGS_EXTENDED;
  freerdp_input_send_keyboard_event(input, flags, sc.scancode);
#endif
}

void FrdpEngineCore::sendMacKey(int keyCode, bool isDown) {
  if (!connected_.load()) return;

#if FRDP_HAS_FREERDP
  std::lock_guard<std::mutex> lock(stateMutex_);
  if (!instance_) return;
  auto* input = instance_->context ? instance_->context->input : nullptr;
  if (!input) return;

  const FrdpScancode sc = FrdpMacKeycodeToScancode(keyCode);
  if (sc.scancode == 0) return;

  UINT16 flags = isDown ? 0 : KBD_FLAGS_RELEASE;
  if (sc.extended) flags |= KBD_FLAGS_EXTENDED;
  freerdp_input_send_keyboard_event(input, flags, sc.scancode);
#endif
}

// MARK: - Clipboard ---------------------------------------------------------

void FrdpEngineCore::sendLocalClipboardText(const std::string& utf8Text) {
#if FRDP_HAS_FREERDP
  if (clipboardManager_) {
    clipboardManager_->onLocalClipboardChanged(utf8Text);
  }
#else
  (void)utf8Text;
#endif
}

// MARK: - Worker loop -------------------------------------------------------

void FrdpEngineCore::runLoop() {
  // 1ms timeout: keeps frame delivery latency under 2ms.
  // Do NOT raise — 16ms causes visible input/rendering lag even at 30fps.
  constexpr DWORD kMaxEventHandles = 64;
  constexpr DWORD kWaitTimeoutMs   = 5;

  while (running_.load()) {
#if FRDP_HAS_FREERDP
    HANDLE handles[kMaxEventHandles];
    DWORD  eventCount = 0;
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      if (!instance_) break;
      eventCount = freerdp_get_event_handles(instance_->context, handles, kMaxEventHandles);
    }

    if (eventCount > 0) {
      WaitForMultipleObjects(eventCount, handles, FALSE, kWaitTimeoutMs);
    } else {
      // No handles yet (e.g., mid-connect): yield briefly.
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    if (!running_.load()) break;

    bool connectionDropped = false;
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      if (instance_ && !freerdp_check_event_handles(instance_->context)) {
        connected_.store(false);
        running_.store(false);
        connectionDropped = true;
      }
    }
    if (connectionDropped) {
      notifyConnectionStateChange(false);
      break;
    }
#else
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
#endif
  }
}

void FrdpEngineCore::notifyConnectionStateChange(bool connected) {
  ConnectionStateCallback callback;
  {
    std::lock_guard<std::mutex> lock(connectionCallbackMutex_);
    callback = connectionStateCallback_;
  }
  if (callback) {
    callback(connected);
  }
}

// MARK: - FreeRDP static registry ------------------------------------------

#if FRDP_HAS_FREERDP

void FrdpEngineCore::registerInstanceOwner(freerdp* instance, FrdpEngineCore* owner) {
  std::lock_guard<std::mutex> lock(instanceOwnerMutex());
  instanceOwnerMap()[instance] = owner;
}

void FrdpEngineCore::unregisterInstanceOwner(freerdp* instance) {
  std::lock_guard<std::mutex> lock(instanceOwnerMutex());
  instanceOwnerMap().erase(instance);
}

FrdpEngineCore* FrdpEngineCore::lookupInstanceOwner(freerdp* instance) {
  std::lock_guard<std::mutex> lock(instanceOwnerMutex());
  const auto it = instanceOwnerMap().find(instance);
  return it != instanceOwnerMap().end() ? it->second : nullptr;
}

std::unordered_map<freerdp*, FrdpEngineCore*>& FrdpEngineCore::instanceOwnerMap() {
  static std::unordered_map<freerdp*, FrdpEngineCore*> map;
  return map;
}

std::mutex& FrdpEngineCore::instanceOwnerMutex() {
  static std::mutex mutex;
  return mutex;
}

// MARK: - FreeRDP callbacks -------------------------------------------------

BOOL FrdpEngineCore::onPreConnect(freerdp* instance) {
  if (!instance || !instance->context) return FALSE;
  if (!instance->context->settings) return FALSE;

  PubSub_SubscribeChannelConnected(instance->context->pubSub,
                                   &FrdpEngineCore::onChannelConnected);
  PubSub_SubscribeChannelDisconnected(instance->context->pubSub,
                                      &FrdpEngineCore::onChannelDisconnected);

  const bool clipboardEnabled =
      freerdp_settings_get_bool(instance->context->settings, FreeRDP_RedirectClipboard);

  if (!clipboardEnabled) {
#if defined(WITH_CHANNELS)
    if (!freerdp_get_current_addin_provider()) {
      if (freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0) !=
          CHANNEL_RC_OK) {
        return FALSE;
      }
    }
#endif
    if (!freerdp_client_load_addins(instance->context->channels,
                                    instance->context->settings)) {
      return FALSE;
    }
  }

  return TRUE;
}

BOOL FrdpEngineCore::onLoadChannels(freerdp* instance) {
  if (!instance || !instance->context) return FALSE;
  auto* settings = instance->context->settings;
  auto* channels = instance->context->channels;
  if (!settings || !channels) return FALSE;

#if defined(WITH_CHANNELS)
  // In embedded flows we bypass freerdp_client_context_new(), so we must
  // register the static addin provider explicitly (same as client/common).
  // This callback is invoked on the fresh channels object created by
  // utils_reload_channels(), which is where addins must be loaded.
  freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0);
#endif

  return freerdp_client_load_addins(channels, settings) ? TRUE : FALSE;
}

BOOL FrdpEngineCore::onPostConnect(freerdp* instance) {
  if (!instance || !instance->context) return FALSE;
  if (!gdi_init(instance, PIXEL_FORMAT_BGRA32))   return FALSE;

  if (instance->context->update) {
    instance->context->update->BeginPaint = &FrdpEngineCore::onBeginPaint;
    instance->context->update->EndPaint   = &FrdpEngineCore::onEndPaint;
  }

  return TRUE;
}

void FrdpEngineCore::onChannelConnected(void* context, const ChannelConnectedEventArgs* e) {
  if (!context || !e) return;
  auto* rdpCtx = static_cast<rdpContext*>(context);
  if (!rdpCtx->instance) return;
  auto* core = lookupInstanceOwner(rdpCtx->instance);
  if (!core) return;

  if (strcmp(e->name, RDPGFX_CHANNEL_NAME) == 0) {
    if (!e->pInterface || !rdpCtx->gdi) return;
    gdi_graphics_pipeline_init(rdpCtx->gdi,
                               static_cast<RdpgfxClientContext*>(e->pInterface));
    return;
  }

  if (strcmp(e->name, CLIPRDR_SVC_CHANNEL_NAME) == 0) {
    auto* cliprdrCtx = reinterpret_cast<CliprdrClientContext*>(e->pInterface);
    if (!cliprdrCtx || !core->clipboardManager_) return;

    core->clipboardManager_->initialize(cliprdrCtx);
  }
}

void FrdpEngineCore::onChannelDisconnected(void* context, const ChannelDisconnectedEventArgs* e) {
  if (!context || !e) return;
  auto* rdpCtx = static_cast<rdpContext*>(context);
  if (!rdpCtx->instance) return;
  auto* core = lookupInstanceOwner(rdpCtx->instance);
  if (!core) return;

  if (strcmp(e->name, RDPGFX_CHANNEL_NAME) == 0) {
    if (!e->pInterface || !rdpCtx->gdi) return;
    gdi_graphics_pipeline_uninit(rdpCtx->gdi,
                                 static_cast<RdpgfxClientContext*>(e->pInterface));
    return;
  }

  if (strcmp(e->name, CLIPRDR_SVC_CHANNEL_NAME) == 0) {
    if (core->clipboardManager_) {
      core->clipboardManager_->uninitialize();
    }
  }
}

BOOL FrdpEngineCore::onBeginPaint(rdpContext* /*context*/) { return TRUE; }

BOOL FrdpEngineCore::onEndPaint(rdpContext* context) {
  if (!context || !context->instance) return TRUE;
  auto* core = lookupInstanceOwner(context->instance);
  if (core) core->emitFrameFromFreeRdp();
  return TRUE;
}

void FrdpEngineCore::emitFrameFromFreeRdp() {
  if (!instance_ || !instance_->context || !instance_->context->gdi) return;

  rdpGdi* gdi = instance_->context->gdi;
  if (!gdi->primary_buffer || gdi->width <= 0 || gdi->height <= 0 || gdi->stride <= 0)
    return;

  FrameCallback callback;
  {
    std::lock_guard<std::mutex> lock(frameCallbackMutex_);
    callback = frameCallback_;
  }

  if (!callback) return;
  callback(gdi->primary_buffer, gdi->width, gdi->height, gdi->stride);
}

// MARK: - FreeRdpDeleter ---------------------------------------------------

void FrdpEngineCore::FreeRdpDeleter::operator()(freerdp* instance) const {
  if (!instance) return;
  if (instance->context && instance->context->gdi) gdi_free(instance);
  if (instance->context) freerdp_context_free(instance);
  freerdp_free(instance);
}

#endif // FRDP_HAS_FREERDP
