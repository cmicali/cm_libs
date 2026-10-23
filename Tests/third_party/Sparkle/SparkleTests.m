//
//  SparkleTests.m
//
//  The vendored Sparkle framework links, embeds, and loads: an unstarted
//  standard controller has an updater.
//

#import <XCTest/XCTest.h>
#import <Sparkle/Sparkle.h>

@interface SparkleTests : XCTestCase
@end

@implementation SparkleTests

- (void)testAnUnstartedControllerHasAnUpdater {
    SPUStandardUpdaterController *controller = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:NO
                                                                                              updaterDelegate:nil
                                                                                           userDriverDelegate:nil];
    XCTAssertNotNil(controller.updater);
    XCTAssertFalse(controller.updater.sessionInProgress);
}

@end
