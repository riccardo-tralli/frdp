#import <AppKit/AppKit.h>

@class FrdpFrameView;

NS_ASSUME_NONNULL_BEGIN

@interface FrdpRenderContainerView : NSView

- (instancetype)initWithFrameView:(FrdpFrameView*)frameView;

@end

NS_ASSUME_NONNULL_END
