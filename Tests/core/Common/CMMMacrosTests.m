//
//  CMMMacrosTests.m
//
//  The realtime brackets compile a checked function and leave it callable.
//

#import <XCTest/XCTest.h>

int CMMCommonProbeAdd(int a, int b);

@interface CMMMacrosTests : XCTestCase
@end

@implementation CMMMacrosTests

- (void)testCheckedFunctionRuns {
    XCTAssertEqual(CMMCommonProbeAdd(2, 3), 5);
}

@end
