#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FrdpConnectionStateDidChangeBlock)(BOOL connected);

/// Optional custom performance settings forwarded to FreeRDP.
/// When passed to `-connectWith…customPerformanceConfig:`, these values
/// completely replace the preset performance profile.
@interface FrdpCustomProfileConfig : NSObject
@property(nonatomic) NSUInteger desktopWidth;
@property(nonatomic) NSUInteger desktopHeight;
/// Numeric FreeRDP CONNECTION_TYPE_* value (1=modem … 7=autodetect).
@property(nonatomic) NSUInteger connectionType;
@property(nonatomic) NSUInteger colorDepth;
@property(nonatomic) BOOL disableWallpaper;
@property(nonatomic) BOOL disableFullWindowDrag;
@property(nonatomic) BOOL disableMenuAnimations;
@property(nonatomic) BOOL disableThemes;
@property(nonatomic) BOOL allowDesktopComposition;
@property(nonatomic) BOOL allowFontSmoothing;
@property(nonatomic) BOOL gfxSurfaceCommandsEnabled;
@property(nonatomic) BOOL gfxProgressive;
@property(nonatomic) BOOL gfxProgressiveV2;
@property(nonatomic) BOOL gfxPlanar;
@property(nonatomic) BOOL gfxH264;
@property(nonatomic) BOOL gfxAvc444;
@property(nonatomic) BOOL gfxAvc444V2;
@end

@interface FrdpRdpEngineAdapter : NSObject

@property(nonatomic, readonly) NSView *renderView;
@property(nonatomic, readonly, getter=isConnected) BOOL connected;
@property(nonatomic, copy, nullable) FrdpConnectionStateDidChangeBlock connectionStateDidChange;
/// Called on the main thread whenever the remote (RDP) host places new text
/// on its clipboard.  Use this to write NSPasteboard and optionally notify
/// the Flutter layer.
@property(nonatomic, copy, nullable) void (^remoteClipboardDidChange)(NSString *text);

- (instancetype)init;

- (BOOL)connectWithHost:(NSString *)host
                   port:(NSInteger)port
               username:(NSString *)username
               password:(NSString *)password
                 domain:(nullable NSString *)domain
      ignoreCertificate:(BOOL)ignoreCertificate
              enableClipboard:(BOOL)enableClipboard
     performanceProfile:(NSString *)performanceProfile
              renderingBackend:(NSString *)renderingBackend
  customPerformanceConfig:(nullable FrdpCustomProfileConfig *)customConfig
                  error:(NSError **)error;

- (void)disconnect;

- (void)sendPointerEventWithX:(double)x y:(double)y buttons:(NSInteger)buttons;

- (void)sendPointerEventWithX:(double)x
                            y:(double)y
                      buttons:(NSInteger)buttons
                    viewWidth:(double)viewWidth
                   viewHeight:(double)viewHeight;

- (void)sendScrollEventWithDeltaX:(double)deltaX deltaY:(double)deltaY;

- (void)sendKeyEventWithKeyCode:(NSInteger)keyCode isDown:(BOOL)isDown;

- (void)sendMacKeyEventWithKeyCode:(NSInteger)keyCode isDown:(BOOL)isDown;

/// Forward local clipboard text to the remote (RDP) host.
/// Safe to call from any thread; internally dispatched as needed.
- (void)sendLocalClipboardText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
