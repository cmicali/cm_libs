//
//  DrMp3Tests.m
//
//  The vendored dr_mp3 builds and links on its own: it names its version, and
//  its frame decoder finds no frame in silence.
//

#import <XCTest/XCTest.h>

#include "dr_mp3/dr_mp3.h"

@interface DrMp3Tests : XCTestCase
@end

@implementation DrMp3Tests

- (void)testNamesItsVersion {
    XCTAssertTrue(strlen(drmp3_version_string()) > 0);
}

- (void)testFindsNoFrameInSilence {
    drmp3dec decoder;
    drmp3dec_init(&decoder);
    uint8_t silence[1024] = {0};
    float pcm[DRMP3_MAX_SAMPLES_PER_FRAME];
    drmp3dec_frame_info info;
    XCTAssertEqual(drmp3dec_decode_frame(&decoder, silence, sizeof silence, pcm, &info), 0);
}

@end
