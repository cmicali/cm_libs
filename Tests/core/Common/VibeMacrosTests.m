//
//  VibeMacrosTests.m
//
//  The realtime brackets compile a checked function and leave it callable.
//

#import <XCTest/XCTest.h>

int VibeCommonProbeAdd(int a, int b);

@interface VibeMacrosTests : XCTestCase
@end

@implementation VibeMacrosTests

- (void)testCheckedFunctionRuns {
    XCTAssertEqual(VibeCommonProbeAdd(2, 3), 5);
}

@end
