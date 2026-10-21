//
//  DrFlacTests.m
//
//  The vendored dr_flac builds and links on its own: it names its version, and
//  it refuses bytes that are not FLAC.
//

#import <XCTest/XCTest.h>

#include "dr_flac/dr_flac.h"

@interface DrFlacTests : XCTestCase
@end

@implementation DrFlacTests

- (void)testNamesItsVersion {
    XCTAssertTrue(strlen(drflac_version_string()) > 0);
}

- (void)testRefusesBytesThatAreNotFLAC {
    uint8_t junk[64] = {0};
    XCTAssertTrue(drflac_open_memory(junk, sizeof junk, NULL) == NULL);
}

@end
