//
//  CMMMacrosTests.m
//

#import <XCTest/XCTest.h>
#import "CMMMacros.h"

static NSMutableArray<NSArray *> *gMirrored;

static void CMMTestMirror(os_log_type_t type, NSString *message) {
    [gMirrored addObject:@[@(type), message]];
}

@interface CMMMacrosTests : XCTestCase
@end

@implementation CMMMacrosTests

- (void)setUp {
    gMirrored = [NSMutableArray array];
    CMMLogMirror = CMMTestMirror;
}

- (void)tearDown {
    CMMLogMirror = NULL;
    gMirrored = nil;
}

- (void)testTheMirrorGetsEachMessageFormattedWithItsType {
    LogWarn(@"warn %d", 1);
    LogError(@"error %@", @"two");
    XCTAssertEqualObjects(gMirrored, (@[@[@(OS_LOG_TYPE_DEFAULT), @"warn 1"],
                                       @[@(OS_LOG_TYPE_ERROR), @"error two"]]));
}

- (void)testTheMirrorGetsALevelTheLogWouldDrop {
    LogDebug(@"debug %d", 3);
    XCTAssertEqual(gMirrored.count, 1u);
    XCTAssertEqualObjects(gMirrored.firstObject.lastObject, @"debug 3");
}

- (void)testNoMirrorGetsNothing {
    CMMLogMirror = NULL;
    LogWarn(@"unmirrored");
    XCTAssertEqual(gMirrored.count, 0u);
}

- (void)testATimedStepLogsOnlyWhenSlowWithoutVerboseLogging {
    LogTiming(NO, @"fast");
    LogTiming(YES, @"slow");
#if VIBE_VERBOSE_LOGGING
    XCTAssertEqual(gMirrored.count, 2u);
#else
    XCTAssertEqual(gMirrored.count, 1u);
    XCTAssertEqualObjects(gMirrored.firstObject.lastObject, @"slow");
#endif
}

@end
