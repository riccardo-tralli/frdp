#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// FrdpFrameView
//
// An NSView subclass that displays a single CGImage frame (BGRA, 32-bit)
// using its CALayer.  Thread-safe: +updateImage: must be called on the main
// thread; the view itself is otherwise a plain NSView.
// ---------------------------------------------------------------------------
@interface FrdpFrameView : NSView

/// Replace the currently displayed frame.  Must be called on the main thread.
- (void)updateImage:(CGImageRef)image;

@end

// ---------------------------------------------------------------------------
// FrdpFrameRenderer
//
// Manages the two-stage frame pipeline:
//   worker thread  →  _frameProcessingQueue (CGImage creation)
//                  →  main queue             (FrdpFrameView update)
//
// Backpressure: at most one frame is in flight at any time (_pending flag).
// ---------------------------------------------------------------------------
@interface FrdpFrameRenderer : NSObject

@property(nonatomic, readonly) FrdpFrameView* frameView;

- (instancetype)init;

/// Submit a raw BGRA frame from any thread.  Drops the frame silently if a
/// previous frame is still being processed (backpressure).
- (void)submitFrameWithData:(const uint8_t*)data
                      width:(int)width
                     height:(int)height
                     stride:(int)stride;

@end

NS_ASSUME_NONNULL_END
