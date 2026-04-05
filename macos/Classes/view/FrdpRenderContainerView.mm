#import "FrdpRenderContainerView.h"
#import "FrdpFrameRenderer.h"

@implementation FrdpRenderContainerView {
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

  return self;
}

@end
