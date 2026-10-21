//
//  VibeWorkTallyTests.m
//
//  The signposts feed the tally while a window is open, and only then. This
//  bundle defines VIBE_SIGNPOSTS, as an app's Debug build does.
//

#import <XCTest/XCTest.h>
#import "VibeMacros.h"

@interface VibeWorkTallyTests : XCTestCase
@end

@implementation VibeWorkTallyTests

- (void)tearDown {
    VibeWorkTallyTakeWindow();
}

- (void)testAWindowCountsEachSignpostByName {
    VibeWorkTallyBegin("test");
    VibeSignpostBegin(timed);
    VibeSignpostEnd(timed);
    VibeSignpostCount(counted);
    VibeTallyCount(counted);

    NSDictionary *window = VibeWorkTallyTakeWindow();
    XCTAssertEqualObjects(window[@"active"], @YES);
    XCTAssertEqualObjects(window[@"label"], @"test");
    XCTAssertEqualObjects(window[@"work"][@"timed"][@"count"], @1);
    XCTAssertEqualObjects(window[@"work"][@"counted"][@"count"], @2);
    XCTAssertEqualObjects(window[@"work"][@"counted"][@"totalMs"], @0, @"a count carries no time");
}

- (void)testNothingIsTalliedWithNoWindowOpen {
    VibeTallyCount(stray);
    NSDictionary *window = VibeWorkTallyTakeWindow();
    XCTAssertEqualObjects(window[@"active"], @NO);
    XCTAssertEqual([window[@"work"] count], 0u);
}

- (void)testEndingAWindowClosesIt {
    VibeWorkTallyBegin("closed");
    VibeTallyCount(once);
    VibeWorkTallyEnd();
    XCTAssertEqualObjects(VibeWorkTallyTakeWindow()[@"active"], @NO, @"a second close finds nothing");
}

- (void)testANewWindowDropsThePreviousCounts {
    VibeWorkTallyBegin("first");
    VibeTallyCount(old);
    VibeWorkTallyBegin("second");
    NSDictionary *window = VibeWorkTallyTakeWindow();
    XCTAssertEqualObjects(window[@"label"], @"second");
    XCTAssertNil(window[@"work"][@"old"]);
}

@end
