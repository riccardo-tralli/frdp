#include "FrdpClipboardManager.hpp"

#import <Foundation/Foundation.h>

#if FRDP_HAS_CLIPRDR

// CF_UNICODETEXT (Windows format ID 13): UTF-16LE, null-terminated.
static constexpr UINT32 kCFUnicodeText = 13;
// CF_TEXT (Windows format ID 1): ANSI codepage bytes, null-terminated.
static constexpr UINT32 kCFText = 1;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void FrdpClipboardManager::initialize(CliprdrClientContext* context) {
  std::lock_guard<std::mutex> lock(mutex_);

  context_     = context;
  serverReady_ = false;

  if (!context_) return;

  // Store a back-pointer so static callbacks can reach this instance.
  context_->custom = this;

  // Register server→client callbacks.
  context_->ServerCapabilities       = &FrdpClipboardManager::onServerCapabilities;
  context_->MonitorReady             = &FrdpClipboardManager::onMonitorReady;
  context_->ServerFormatList         = &FrdpClipboardManager::onServerFormatList;
  context_->ServerFormatListResponse = &FrdpClipboardManager::onServerFormatListResponse;
  context_->ServerFormatDataRequest  = &FrdpClipboardManager::onServerFormatDataRequest;
  context_->ServerFormatDataResponse = &FrdpClipboardManager::onServerFormatDataResponse;
}

void FrdpClipboardManager::uninitialize() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (context_) {
    context_->custom = nullptr;
    context_          = nullptr;
  }
  serverReady_    = false;
  hasPendingText_ = false;
}

void FrdpClipboardManager::onLocalClipboardChanged(const std::string& utf8Text) {
  std::lock_guard<std::mutex> lock(mutex_);
  pendingLocalText_ = utf8Text;
  hasPendingText_   = true;

  if (serverReady_ && context_) {
    sendLocalFormatList();
  }
  // If the server is not ready yet, sendLocalFormatList() will be called
  // from onMonitorReady() once the server signals it is ready.
}

// ---------------------------------------------------------------------------
// Static helper — recover FrdpClipboardManager* from context->custom.
// ---------------------------------------------------------------------------

FrdpClipboardManager* FrdpClipboardManager::fromContext(CliprdrClientContext* ctx) {
  if (!ctx || !ctx->custom) return nullptr;
  return static_cast<FrdpClipboardManager*>(ctx->custom);
}

UINT FrdpClipboardManager::sendClientCapabilities(CliprdrClientContext* context) {
  if (!context) return CHANNEL_RC_OK;

  CLIPRDR_GENERAL_CAPABILITY_SET gen = {};
  gen.capabilitySetType   = CB_CAPSTYPE_GENERAL;
  gen.capabilitySetLength = CB_CAPSTYPE_GENERAL_LEN;
  gen.version             = CB_CAPS_VERSION_2;
  gen.generalFlags        = CB_USE_LONG_FORMAT_NAMES;

  CLIPRDR_CAPABILITIES caps = {};
  caps.common.msgType = CB_CLIP_CAPS;
  caps.common.msgFlags = 0;
  caps.common.dataLen = 4 + CB_CAPSTYPE_GENERAL_LEN;
  caps.cCapabilitiesSets = 1;
  caps.capabilitySets = reinterpret_cast<CLIPRDR_CAPABILITY_SET*>(&gen);

  const UINT rc = context->ClientCapabilities(context, &caps);
  return rc;
}

// ---------------------------------------------------------------------------
// cliprdr callbacks
// ---------------------------------------------------------------------------

UINT FrdpClipboardManager::onServerCapabilities(
    CliprdrClientContext*       context,
    const CLIPRDR_CAPABILITIES* /*capabilities*/) {
  (void)sendClientCapabilities(context);
  return CHANNEL_RC_OK;
}

UINT FrdpClipboardManager::onMonitorReady(CliprdrClientContext*        context,
                                           const CLIPRDR_MONITOR_READY* /*monitorReady*/) {
  auto* mgr = fromContext(context);
  if (!mgr) return CHANNEL_RC_OK;

  // Some servers rely on capabilities being sent after MonitorReady.
  (void)sendClientCapabilities(context);

  std::lock_guard<std::mutex> lock(mgr->mutex_);
  mgr->serverReady_ = true;

  // Announce local text formats when the server becomes ready.
  mgr->sendLocalFormatList();

  return CHANNEL_RC_OK;
}

UINT FrdpClipboardManager::onServerFormatList(CliprdrClientContext*      context,
                                               const CLIPRDR_FORMAT_LIST* formatList) {
  auto* mgr = fromContext(context);
  if (!mgr) return CHANNEL_RC_OK;

  // Acknowledge the server's format list unconditionally.
  CLIPRDR_FORMAT_LIST_RESPONSE ack = {};
  ack.common.msgType = CB_FORMAT_LIST_RESPONSE;
  ack.common.msgFlags = CB_RESPONSE_OK;
  ack.common.dataLen = 0;
  context->ClientFormatListResponse(context, &ack);

  // Check which text formats the server supports.
  bool hasUnicode = false;
  bool hasAnsi = false;
  if (formatList) {
    for (UINT32 i = 0; i < formatList->numFormats; ++i) {
      if (formatList->formats[i].formatId == kCFUnicodeText) {
        hasUnicode = true;
      }
      if (formatList->formats[i].formatId == kCFText) {
        hasAnsi = true;
      }
    }
  }

  // Prefer Unicode, fall back to ANSI for older servers/apps.
  const UINT32 requestedFormatId = hasUnicode ? kCFUnicodeText : (hasAnsi ? kCFText : 0);
  if (requestedFormatId != 0) {
    CLIPRDR_FORMAT_DATA_REQUEST req = {};
    req.common.msgType = CB_FORMAT_DATA_REQUEST;
    req.common.msgFlags = 0;
    req.common.dataLen = 4;
    req.requestedFormatId = requestedFormatId;
    context->ClientFormatDataRequest(context, &req);
  }

  return CHANNEL_RC_OK;
}

UINT FrdpClipboardManager::onServerFormatListResponse(
    CliprdrClientContext*               /*context*/,
    const CLIPRDR_FORMAT_LIST_RESPONSE* /*response*/) {
  // No action needed; we just wait for a ServerFormatDataRequest if the
  // server wants to paste from our clipboard.
  return CHANNEL_RC_OK;
}

UINT FrdpClipboardManager::onServerFormatDataRequest(
    CliprdrClientContext*              context,
    const CLIPRDR_FORMAT_DATA_REQUEST* request) {
  @autoreleasepool {
    auto* mgr = fromContext(context);
    if (!mgr || !request) return CHANNEL_RC_OK;

    std::lock_guard<std::mutex> lock(mgr->mutex_);

    CLIPRDR_FORMAT_DATA_RESPONSE response = {};

    if ((request->requestedFormatId == kCFUnicodeText || request->requestedFormatId == kCFText) &&
        mgr->hasPendingText_) {
      NSString* str = [NSString stringWithUTF8String:mgr->pendingLocalText_.c_str()];
      if (!str) str = @"";

      NSMutableData* data = nil;
      if (request->requestedFormatId == kCFUnicodeText) {
        // Encode as UTF-16LE, then append a 2-byte null terminator.
        data = [[str dataUsingEncoding:NSUTF16LittleEndianStringEncoding] mutableCopy];
      } else {
        // CF_TEXT uses ANSI bytes; Windows CP-1252 is the usual fallback.
        data = [[str dataUsingEncoding:NSWindowsCP1252StringEncoding
                  allowLossyConversion:YES] mutableCopy];
      }
      if (!data) data = [NSMutableData data];
      if (request->requestedFormatId == kCFUnicodeText) {
        const uint16_t nullTerm = 0;
        [data appendBytes:&nullTerm length:sizeof(nullTerm)];
      } else {
        const uint8_t nullTerm = 0;
        [data appendBytes:&nullTerm length:sizeof(nullTerm)];
      }

      response.common.msgType      = CB_FORMAT_DATA_RESPONSE;
      response.common.msgFlags     = CB_RESPONSE_OK;
      response.common.dataLen      = static_cast<UINT32>(data.length);
      response.requestedFormatData = static_cast<const BYTE*>(data.bytes);
      context->ClientFormatDataResponse(context, &response);
    } else {
      response.common.msgType      = CB_FORMAT_DATA_RESPONSE;
      response.common.msgFlags     = CB_RESPONSE_FAIL;
      response.common.dataLen      = 0;
      response.requestedFormatData = nullptr;
      context->ClientFormatDataResponse(context, &response);
    }

    return CHANNEL_RC_OK;
  }
}

UINT FrdpClipboardManager::onServerFormatDataResponse(
    CliprdrClientContext*               context,
    const CLIPRDR_FORMAT_DATA_RESPONSE* response) {
  @autoreleasepool {
    auto* mgr = fromContext(context);
    if (!mgr || !response)                       return CHANNEL_RC_OK;
    if (!(response->common.msgFlags & CB_RESPONSE_OK))   return CHANNEL_RC_OK;
    if (!response->requestedFormatData || response->common.dataLen < 2) return CHANNEL_RC_OK;

    NSData* raw = [NSData dataWithBytes:response->requestedFormatData
                                 length:response->common.dataLen];

    NSString* text = nil;
    const UINT32 requestedFormatId = context ? context->lastRequestedFormatId : 0;
    if (requestedFormatId == kCFText) {
      text = [[NSString alloc] initWithData:raw encoding:NSWindowsCP1252StringEncoding];
      if (!text) text = [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding];
    } else {
      // Default to Unicode for CF_UNICODETEXT and unknown cases.
      text = [[NSString alloc] initWithData:raw encoding:NSUTF16LittleEndianStringEncoding];
    }
    if (!text) return CHANNEL_RC_OK;

    // Strip trailing NUL characters that Windows appends (U+0000).
    NSMutableCharacterSet* nullSet = [NSMutableCharacterSet new];
    [nullSet addCharactersInRange:NSMakeRange(0, 1)];
    text = [text stringByTrimmingCharactersInSet:nullSet];

    const std::string utf8 = text.UTF8String ? text.UTF8String : "";

    TextReceivedCallback callback;
    {
      std::lock_guard<std::mutex> lock(mgr->mutex_);
      callback = mgr->textReceivedCallback_;
    }

    if (callback && !utf8.empty()) {
      callback(utf8);
    }

    return CHANNEL_RC_OK;
  }
}

// ---------------------------------------------------------------------------
// Private helper — send our format list to the server.
// MUST be called with mutex_ held.
// ---------------------------------------------------------------------------

bool FrdpClipboardManager::sendLocalFormatList() {
  if (!context_) return false;

  CLIPRDR_FORMAT formats[2] = {};
  formats[0].formatId = kCFUnicodeText;
  formats[0].formatName = nullptr;
  formats[1].formatId = kCFText;
  formats[1].formatName = nullptr;

  CLIPRDR_FORMAT_LIST list = {};
  list.common.msgType      = CB_FORMAT_LIST;
  list.common.msgFlags     = 0;
  list.numFormats          = 2;
  list.common.dataLen      = list.numFormats * 36;
  list.formats             = formats;

  const UINT rc = context_->ClientFormatList(context_, &list);
  return rc == CHANNEL_RC_OK;
}

#endif  // FRDP_HAS_CLIPRDR
