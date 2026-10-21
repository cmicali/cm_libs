//
//  VibeWeakProxyTests.m
//
//  The proxy forwards to a live target, keeps it from nothing, and drops
//  messages once the target is gone.
//

#import <XCTest/XCTest.h>
#import "VibeWeakProxy.h"

@interface VibeWeakProxyTarget : NSObject
@property (nonatomic) NSUInteger pings;
- (void)ping;
@end

@implementation VibeWeakProxyTarget
- (void)ping {
    self.pings++;
}
@end

@interface VibeWeakProxyTests : XCTestCase
@end

@implementation VibeWeakProxyTests

- (void)testALiveTargetGetsTheMessage {
    VibeWeakProxyTarget *target = [VibeWeakProxyTarget new];
    id proxy = [VibeWeakProxy proxyWithTarget:target];
    [proxy ping];
    XCTAssertEqual(target.pings, 1u);
}

- (void)testTheProxyDoesNotKeepItsTarget {
    __weak VibeWeakProxyTarget *weakTarget = nil;
    id proxy = nil;
    @autoreleasepool {
        VibeWeakProxyTarget *target = [VibeWeakProxyTarget new];
        weakTarget = target;
        proxy = [VibeWeakProxy proxyWithTarget:target];
    }
    XCTAssertNil(weakTarget);
    XCTAssertNoThrow([proxy ping], @"a message to a dead target does nothing");
}

@end
