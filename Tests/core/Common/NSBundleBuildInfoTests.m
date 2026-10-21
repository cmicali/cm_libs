//
//  NSBundleBuildInfoTests.m
//
//  The version line names the configuration. With no VibeGitInfo.h, as in
//  this repo's builds, the git fields read as unknown.
//

#import <XCTest/XCTest.h>
#import "NSBundle+BuildInfo.h"

@interface NSBundleBuildInfoTests : XCTestCase
@end

@implementation NSBundleBuildInfoTests

- (void)testTheVersionNamesTheConfiguration {
    NSString *version = NSBundle.mainBundle.vibeVersionString;
#if DEBUG
    XCTAssertTrue([version hasSuffix:@" · Debug"], @"%@", version);
#else
    XCTAssertTrue([version hasSuffix:@" · Release"], @"%@", version);
#endif
}

- (void)testTheGitFieldsAreUnknownWithoutTheGeneratedHeader {
    XCTAssertEqualObjects(NSBundle.mainBundle.vibeGitString, @"unknown (not a git checkout)");
}

- (void)testTheBuildTimeIsTheExecutablesModificationTime {
    NSString *built = NSBundle.mainBundle.vibeBuildTimeString;
    NSRegularExpression *shape = [NSRegularExpression
            regularExpressionWithPattern:@"^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2} [+-]\\d{2}:\\d{2}$"
                                 options:0 error:NULL];
    XCTAssertEqual([shape numberOfMatchesInString:built options:0 range:NSMakeRange(0, built.length)], 1u,
                   @"%@", built);
}

@end
