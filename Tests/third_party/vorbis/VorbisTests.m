//
//  VorbisTests.m
//
//  The vendored libvorbis builds and links on its own: it names its version,
//  and vorbisfile refuses bytes that are not Ogg Vorbis.
//

#import <XCTest/XCTest.h>

#include <vorbis/vorbisfile.h>

@interface VorbisTests : XCTestCase
@end

@implementation VorbisTests

- (void)testNamesItsVersion {
    XCTAssertTrue(strlen(vorbis_version_string()) > 0);
}

// Reads nothing, so the open sees an empty stream.
static size_t ReadNothing(void *ptr, size_t size, size_t count, void *source) {
    return 0;
}

- (void)testRefusesAnEmptyStream {
    OggVorbis_File file;
    ov_callbacks callbacks = {ReadNothing, NULL, NULL, NULL};
    XCTAssertLessThan(ov_open_callbacks(NULL, &file, NULL, 0, callbacks), 0);
}

@end
