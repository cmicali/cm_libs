//
//  DrWavTests.m
//
//  The vendored dr_wav builds and links on its own: it names its version, and
//  it refuses bytes that are not a WAV or AIFF file.
//

#import <XCTest/XCTest.h>

#include "dr_wav/dr_wav.h"

@interface DrWavTests : XCTestCase
@end

@implementation DrWavTests

- (void)testNamesItsVersion {
    XCTAssertTrue(strlen(drwav_version_string()) > 0);
}

- (void)testRefusesBytesThatAreNotWAV {
    uint8_t junk[64] = {0};
    drwav wav;
    XCTAssertFalse(drwav_init_memory(&wav, junk, sizeof junk, NULL));
}

@end
