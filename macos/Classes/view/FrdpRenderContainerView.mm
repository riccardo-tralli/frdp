#import "FrdpRenderContainerView.h"
#import "FrdpFrameRenderer.h"

@implementation FrdpRenderContainerView {
  NSTextField* _statusLabel;
}

- (instancetype)initWithFrameView:(FrdpFrameView*)frameView {
  self = [super initWithFrame:NSMakeRect(0, 0, 640, 360)];
  if (!self) return nil;

  self.wantsLayer = YES;
  self.layer.backgroundColor = NSColor.blackColor.CGColor;

  frameView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:frameView];
  [NSLayoutConstraint activateConstraints:@[
    [frameView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
    [frameView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [frameView.topAnchor      constraintEqualToAnchor:self.topAnchor],
    [frameView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
  ]];

  _statusLabel = [NSTextField labelWithString:@"RDP engine idle"];
  _statusLabel.textColor = NSColor.whiteColor;
  _statusLabel.backgroundColor = [NSColor colorWithWhite:0 alpha:0.45];
  _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:_statusLabel];
  [NSLayoutConstraint activateConstraints:@[
    [_statusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
    [_statusLabel.topAnchor     constraintEqualToAnchor:self.topAnchor constant:12],
  ]];

  return self;
}

- (void)showIdleStatus {
  _statusLabel.stringValue = @"RDP engine idle";
}

- (void)showConnectedStatusForHost:(NSString*)host port:(NSInteger)port {
  _statusLabel.stringValue = [NSString stringWithFormat:@"Embedded RDP connected: %@:%ld", host, (long)port];
}

- (void)showUnavailableStatus {
  _statusLabel.stringValue = @"Embedded RDP unavailable";
}

- (void)showDisconnectedStatus {
  _statusLabel.stringValue = @"RDP engine disconnected";
}

@end
