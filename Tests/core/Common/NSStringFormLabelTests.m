//
//  NSStringFormLabelTests.m
//
//  A trailing form colon goes, in each script's spelling. Nothing else does.
//

#import <XCTest/XCTest.h>
#import "NSString+FormLabel.h"

@interface NSStringFormLabelTests : XCTestCase
@end

@implementation NSStringFormLabelTests

- (void)testTrailingColonGoes {
    XCTAssertEqualObjects(@"Volume:".vibeFormLabel, @"Volume");
    XCTAssertEqualObjects(@"Volume :".vibeFormLabel, @"Volume");
    XCTAssertEqualObjects(@"音量：".vibeFormLabel, @"音量");
}

- (void)testOtherTextStays {
    XCTAssertEqualObjects(@"Volume".vibeFormLabel, @"Volume");
    XCTAssertEqualObjects(@"Ratio: 2:1".vibeFormLabel, @"Ratio: 2:1");
    XCTAssertEqualObjects(@"".vibeFormLabel, @"");
}

@end
