//
//  R8brainTests.mm
//
//  The vendored r8brain builds and links on its own: its C entry points
//  resample a block from 44.1 to 48 kHz.
//

#import <XCTest/XCTest.h>

#include <vector>

#define R8BSRC_DECL
#include "r8brain/DLL/r8bsrc.h"

@interface R8brainTests : XCTestCase
@end

@implementation R8brainTests

- (void)testResamplesABlock {
    CR8BResampler resampler = r8b_create(44100, 48000, 4096, 1.0, r8brr24);
    XCTAssertTrue(resampler != NULL);
    std::vector<double> input(4096, 0.25);
    int produced = 0;
    for (int block = 0; block < 8; block++) {
        double *output = nullptr;
        produced += r8b_process(resampler, input.data(), (int)input.size(), output);
    }
    r8b_delete(resampler);
    XCTAssertGreaterThan(produced, 0);
}

@end
