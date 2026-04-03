#import "FrdpRdpEngineAdapter.h"
#import "FrdpFrameRenderer.h"
#include "FrdpEngineCore.hpp"

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
  NSTextField*                    _statusLabel;
}

- (instancetype)init {
  self = [super init];
  if (!self) return nil;

  _core     = std::make_unique<FrdpEngineCore>();
  _renderer = [[FrdpFrameRenderer alloc] init];

  // Container view (black background, fills bounds).
  NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 640, 360)];
  container.wantsLayer = YES;
  container.layer.backgroundColor = NSColor.blackColor.CGColor;

  FrdpFrameView* frameView = _renderer.frameView;
  [container addSubview:frameView];
  [NSLayoutConstraint activateConstraints:@[
    [frameView.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
    [frameView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [frameView.topAnchor      constraintEqualToAnchor:container.topAnchor],
    [frameView.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
  ]];

  _statusLabel = [NSTextField labelWithString:@"RDP engine idle"];
  _statusLabel.textColor       = NSColor.whiteColor;
  _statusLabel.backgroundColor = [NSColor colorWithWhite:0 alpha:0.45];
  _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:_statusLabel];
  [NSLayoutConstraint activateConstraints:@[
    [_statusLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],
    [_statusLabel.topAnchor     constraintEqualToAnchor:container.topAnchor     constant:12],
  ]];

  self.renderView = container;

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
      if (!connected) {
        strongSelf->_statusLabel.stringValue = @"RDP engine disconnected";
      }

      if (strongSelf.connectionStateDidChange) {
        strongSelf.connectionStateDidChange(connected ? YES : NO);
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
                  error:(NSError* __autoreleasing _Nullable*)error {
  std::string msg;
  const bool ok = _core->connect(
      host.UTF8String,
      static_cast<int>(port),
      username.UTF8String,
      password.UTF8String,
      domain ? domain.UTF8String : "",
      ignoreCertificate == YES,
      performanceProfile.UTF8String,
      msg);

  self.connected = ok;
  if (ok) {
    _statusLabel.stringValue =
        [NSString stringWithFormat:@"Embedded RDP connected: %@:%ld", host, (long)port];
    return YES;
  }

  _statusLabel.stringValue = @"Embedded RDP unavailable";
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
  _statusLabel.stringValue = @"RDP engine disconnected";
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

@end
