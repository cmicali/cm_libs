//
//  WindowAnimationTests.m
//  ControlsTests
//
//  Compiles WindowAnimation.h in its own piece, and pins the one timing.
//

#import <XCTest/XCTest.h>
#import "WindowAnimation.h"

@interface WindowAnimationTests : XCTestCase
@end

@implementation WindowAnimationTests

- (void)testEveryResizeTakesOneFixedTime {
    XCTAssertEqual(kWindowResizeAnimationDuration, 0.12);
}

@end
