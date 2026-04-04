#import <AppKit/AppKit.h>

@class FrdpFrameView;

NS_ASSUME_NONNULL_BEGIN

@interface FrdpRenderContainerView : NSView

- (instancetype)initWithFrameView:(FrdpFrameView*)frameView;

- (void)showIdleStatus;
- (void)showConnectedStatusForHost:(NSString*)host port:(NSInteger)port;
- (void)showUnavailableStatus;
- (void)showDisconnectedStatus;

@end

NS_ASSUME_NONNULL_END
