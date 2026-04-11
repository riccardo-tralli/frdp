#import "FrdpRdpEngineAdapter.h"
#import "FrdpFrameRenderer.h"
#import "FrdpRenderContainerView.h"
#include "FrdpEngineCore.hpp"

// ---------------------------------------------------------------------------
// FrdpCustomProfileConfig
// ---------------------------------------------------------------------------

@implementation FrdpCustomProfileConfig
@end

// ---------------------------------------------------------------------------
// FrdpRdpEngineAdapter
//
// Thin Objective-C bridge between Swift callers and FrdpEngineCore (C++).
// Owns the FrdpFrameRenderer (Cocoa view hierarchy) and wires the frame
// callback from the engine core into the renderer.
// ---------------------------------------------------------------------------

@interface FrdpRdpEngineAdapter ()
@property(nonatomic, readwrite) NSView*               renderView;
@property(nonatomic, readwrite, getter=isConnected) BOOL connected;
@end

@implementation FrdpRdpEngineAdapter {
  std::unique_ptr<FrdpEngineCore> _core;
  FrdpFrameRenderer*              _renderer;
  FrdpRenderContainerView*        _containerView;
}

- (instancetype)init {
  self = [super init];
  if (!self) return nil;

  _core     = std::make_unique<FrdpEngineCore>();
  _renderer = [[FrdpFrameRenderer alloc] init];

  _containerView = [[FrdpRenderContainerView alloc] initWithFrameView:_renderer.frameView];
  self.renderView = _containerView;

  // Wire frame callback: engine core → renderer (called from worker thread).
  __weak FrdpFrameRenderer* weakRenderer = _renderer;
  _core->setFrameCallback([weakRenderer](const uint8_t* data, int w, int h, int stride) {
    [weakRenderer submitFrameWithData:data width:w height:h stride:stride];
  });

  __weak FrdpRdpEngineAdapter* weakSelf = self;
  _core->setConnectionStateCallback([weakSelf](bool connected) {
    dispatch_async(dispatch_get_main_queue(), ^{
      FrdpRdpEngineAdapter* strongSelf = weakSelf;
      if (!strongSelf) return;

      strongSelf.connected = connected ? YES : NO;

      if (strongSelf.connectionStateDidChange) {
        strongSelf.connectionStateDidChange(connected ? YES : NO);
      }
    });
  });

  _core->setClipboardCallback([weakSelf](const std::string& utf8Text) {
    NSString* text = [NSString stringWithUTF8String:utf8Text.c_str()];
    if (!text) return;
    dispatch_async(dispatch_get_main_queue(), ^{
      FrdpRdpEngineAdapter* strongSelf = weakSelf;
      if (!strongSelf) return;
      if (strongSelf.remoteClipboardDidChange) {
        strongSelf.remoteClipboardDidChange(text);
      }
    });
  });

  return self;
}

// MARK: - Connection --------------------------------------------------------

- (BOOL)connectWithHost:(NSString*)host
                   port:(NSInteger)port
               username:(NSString*)username
               password:(NSString*)password
                 domain:(nullable NSString*)domain
      ignoreCertificate:(BOOL)ignoreCertificate
     performanceProfile:(NSString*)performanceProfile
              renderingBackend:(NSString*)renderingBackend
  customPerformanceConfig:(nullable FrdpCustomProfileConfig*)customConfig
                  error:(NSError* __autoreleasing _Nullable*)error {
  FrdpFreeRdpConnectConfig config;
  config.host                = host.UTF8String;
  config.port                = static_cast<int>(port);
  config.username            = username.UTF8String;
  config.password            = password.UTF8String;
  config.domain              = domain ? domain.UTF8String : "";
  config.ignoreCertificate   = ignoreCertificate == YES;
  config.performanceProfile  = performanceProfile.UTF8String;
  config.renderingBackend    = renderingBackend.UTF8String;

  if (customConfig) {
    config.hasCustomPerformanceProfile = true;
    config.customPerformanceProfile.desktopWidth            = static_cast<uint32_t>(customConfig.desktopWidth);
    config.customPerformanceProfile.desktopHeight           = static_cast<uint32_t>(customConfig.desktopHeight);
    config.customPerformanceProfile.connectionType          = static_cast<uint32_t>(customConfig.connectionType);
    config.customPerformanceProfile.colorDepth              = static_cast<uint32_t>(customConfig.colorDepth);
    config.customPerformanceProfile.disableWallpaper        = customConfig.disableWallpaper == YES;
    config.customPerformanceProfile.disableFullWindowDrag   = customConfig.disableFullWindowDrag == YES;
    config.customPerformanceProfile.disableMenuAnimations   = customConfig.disableMenuAnimations == YES;
    config.customPerformanceProfile.disableThemes           = customConfig.disableThemes == YES;
    config.customPerformanceProfile.allowDesktopComposition = customConfig.allowDesktopComposition == YES;
    config.customPerformanceProfile.allowFontSmoothing      = customConfig.allowFontSmoothing == YES;
    config.customPerformanceProfile.gfxSurfaceCommandsEnabled = customConfig.gfxSurfaceCommandsEnabled == YES;
    config.customPerformanceProfile.gfxProgressive            = customConfig.gfxProgressive == YES;
    config.customPerformanceProfile.gfxProgressiveV2          = customConfig.gfxProgressiveV2 == YES;
    config.customPerformanceProfile.gfxPlanar                 = customConfig.gfxPlanar == YES;
    config.customPerformanceProfile.gfxH264                   = customConfig.gfxH264 == YES;
    config.customPerformanceProfile.gfxAvc444                 = customConfig.gfxAvc444 == YES;
    config.customPerformanceProfile.gfxAvc444V2               = customConfig.gfxAvc444V2 == YES;
  }

  std::string msg;
  const bool ok = _core->connect(config, msg);

  self.connected = ok;
  if (ok) {
    return YES;
  }

  if (error) {
    *error = [NSError errorWithDomain:@"frdp.engine"
                                 code:1001
                             userInfo:@{NSLocalizedDescriptionKey: @(msg.c_str())}];
  }
  return NO;
}

- (void)disconnect {
  _core->disconnect();
  self.connected = NO;
}

// MARK: - Input forwarding --------------------------------------------------

- (void)sendPointerEventWithX:(double)x y:(double)y buttons:(NSInteger)buttons {
  NSSize sz = self.renderView.bounds.size;
  _core->sendPointer(x, y, static_cast<int>(buttons), sz.width, sz.height);
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
  _core->sendKey(static_cast<int>(keyCode), isDown == YES);
}

- (void)sendMacKeyEventWithKeyCode:(NSInteger)keyCode isDown:(BOOL)isDown {
  _core->sendMacKey(static_cast<int>(keyCode), isDown == YES);
}

// MARK: - Clipboard forwarding ---------------------------------------------

- (void)sendLocalClipboardText:(NSString*)text {
  if (!text) return;
  const char* utf8 = text.UTF8String;
  if (!utf8) return;
  _core->sendLocalClipboardText(std::string(utf8));
}

@end
