#import "FrdpFrameRenderer.h"

#include <atomic>
#include <cstdlib>
#include <cstring>

// ---------------------------------------------------------------------------
// FrdpFrameView
// ---------------------------------------------------------------------------

@implementation FrdpFrameView {
  CGImageRef _image;
}

- (instancetype)init {
  self = [super initWithFrame:NSMakeRect(0, 0, 640, 360)];
  if (self) {
    _image = nullptr;
    self.wantsLayer = YES;
    self.layer.contentsGravity = kCAGravityResize;
    self.layer.opaque = YES;
    self.layer.actions = @{@"contents": [NSNull null]};
  }
  return self;
}

- (void)dealloc {
  if (_image != nullptr) {
    CGImageRelease(_image);
  }
}

- (void)updateImage:(CGImageRef)image {
  if (image == nullptr) return;

  CGImageRef previous = _image;
  _image = CGImageRetain(image);
  self.layer.contents = (__bridge id)_image;
  if (previous != nullptr) {
    CGImageRelease(previous);
  }
}

@end

// ---------------------------------------------------------------------------
// File-scoped helper: CGDataProvider release callback
// ---------------------------------------------------------------------------

static void FrdpReleaseFrameBuffer(void* /*info*/, const void* data, size_t /*size*/) {
  free(const_cast<void*>(data));
}

static bool FrdpComputeFrameSize(int width, int height, int stride, size_t* outBytesPerRow, size_t* outFrameBytes) {
  if (width <= 0 || height <= 0 || stride <= 0) return false;

  constexpr size_t kBytesPerPixel = 4;
  const size_t bytesPerRow = static_cast<size_t>(stride);
  const size_t minBytesPerRow = static_cast<size_t>(width) * kBytesPerPixel;
  if (bytesPerRow < minBytesPerRow) return false;

  const size_t h = static_cast<size_t>(height);
  if (bytesPerRow > (SIZE_MAX / h)) return false;

  *outBytesPerRow = bytesPerRow;
  *outFrameBytes = bytesPerRow * h;
  return true;
}

// ---------------------------------------------------------------------------
// FrdpFrameRenderer
// ---------------------------------------------------------------------------

@implementation FrdpFrameRenderer {
  FrdpFrameView*          _frameView;
  dispatch_queue_t        _processingQueue;
  std::atomic<bool>       _pending;
}

@synthesize frameView = _frameView;

- (instancetype)init {
  self = [super init];
  if (self) {
    _pending.store(false);
    _processingQueue = dispatch_queue_create("com.frdp.frame-processing",
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                QOS_CLASS_USER_INTERACTIVE, 0));
    _frameView = [[FrdpFrameView alloc] init];
    _frameView.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return self;
}

- (void)submitFrameWithData:(const uint8_t*)data
                      width:(int)width
                     height:(int)height
                     stride:(int)stride {
  if (data == nullptr) return;

  size_t bytesPerRow = 0;
  size_t frameBytes = 0;
  if (!FrdpComputeFrameSize(width, height, stride, &bytesPerRow, &frameBytes)) {
    return;
  }

  bool expected = false;
  if (!_pending.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) {
    return; // previous frame still in flight — drop this one
  }

  uint8_t* copied = static_cast<uint8_t*>(malloc(frameBytes));
  if (copied == nullptr) {
    _pending.store(false, std::memory_order_release);
    return;
  }
  memcpy(copied, data, frameBytes);

  __weak FrdpFrameRenderer* weakSelf = self;
  const int capturedWidth  = width;
  const int capturedHeight = height;

  dispatch_async(_processingQueue, ^{
    CGDataProviderRef provider = CGDataProviderCreateWithData(
        nullptr, copied, frameBytes, FrdpReleaseFrameBuffer);
    if (provider == nullptr) {
      free(copied);
      FrdpFrameRenderer* s = weakSelf;
      if (s) s->_pending.store(false, std::memory_order_release);
      return;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo =
        static_cast<CGBitmapInfo>(kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = CGImageCreate(
        static_cast<size_t>(capturedWidth),
        static_cast<size_t>(capturedHeight),
        8, 32, bytesPerRow,
        colorSpace, bitmapInfo,
        provider,
        nullptr, false,
        kCGRenderingIntentDefault);

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    if (image == nullptr) {
      FrdpFrameRenderer* s = weakSelf;
      if (s) s->_pending.store(false, std::memory_order_release);
      return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      FrdpFrameRenderer* s = weakSelf;
      if (s) {
        [s->_frameView updateImage:image];
        s->_pending.store(false, std::memory_order_release);
      }
      CGImageRelease(image);
    });
  });
}

@end
