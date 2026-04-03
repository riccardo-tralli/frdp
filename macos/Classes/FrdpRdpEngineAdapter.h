#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FrdpRdpEngineAdapter : NSObject

@property(nonatomic, readonly) NSView *renderView;
@property(nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)init;

- (BOOL)connectWithHost:(NSString *)host
                   port:(NSInteger)port
               username:(NSString *)username
               password:(NSString *)password
                 domain:(nullable NSString *)domain
      ignoreCertificate:(BOOL)ignoreCertificate
  performanceProfile:(NSString *)performanceProfile
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

@end

NS_ASSUME_NONNULL_END
