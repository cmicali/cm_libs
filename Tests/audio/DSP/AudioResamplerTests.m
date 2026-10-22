//
// The resampler alone: its length, its gain, and what it refuses. A player's
// quality tests hold its quality to its bounds through the player's voice bus,
// at every rate pair the player meets.
//

#import <XCTest/XCTest.h>
#include <math.h>

#import "AudioResampler.h"

enum { kFeedFrames = 4096 };

// A stereo sine of `frames` at `rate`, then silence for as long as the fill asks.
typedef struct {
    double rate;
    uint32_t frames;
    uint32_t next;
    float left[kFeedFrames];
    float right[kFeedFrames];
} SineFeed;

static uint32_t SupplySine(void *userData, uint32_t maxFrames, const float **channels) {
    SineFeed *feed = (SineFeed *)userData;
    uint32_t count = MIN(maxFrames, (uint32_t)kFeedFrames);
    for (uint32_t i = 0; i < count; i++) {
        uint32_t frame = feed->next + i;
        float sample = frame < feed->frames ? (float)(0.5 * sin(2 * M_PI * 1000 * frame / feed->rate)) : 0;
        feed->left[i] = sample;
        feed->right[i] = sample;
    }
    feed->next += count;
    channels[0] = feed->left;
    channels[1] = feed->right;
    return count;
}

@interface AudioResamplerTests : XCTestCase
@end

@implementation AudioResamplerTests

// N frames pushed through with silence come out as round(N × ratio), at the
// sine's gain, both channels alike.
- (void)testASineKeepsItsLengthAndGainAtTheNewRate {
    const double from = 44100, to = 48000;
    SineFeed *feed = calloc(1, sizeof(SineFeed));
    feed->rate = from;
    feed->frames = 44100;
    const uint32_t length = (uint32_t)llround(feed->frames * to / from);
    float *left = calloc(length, sizeof(float)), *right = calloc(length, sizeof(float));
    VibeResampler *resampler = VibeResamplerCreate(from, to, 2);
    XCTAssertTrue(resampler != NULL);
    uint32_t made = 0;
    while (made < length) {
        float *into[2] = {left + made, right + made};
        uint32_t frames = VibeResamplerFill(resampler, SupplySine, feed, MIN(length - made, 4096u), into);
        if (frames == 0) {
            break;
        }
        made += frames;
    }
    VibeResamplerDispose(resampler);
    XCTAssertEqual(made, length);
    // The middle half, clear of the filter's delay at the start and the tail.
    double power = 0;
    for (uint32_t i = length / 4; i < length * 3 / 4; i++) {
        power += (double)left[i] * left[i];
        XCTAssertEqual(left[i], right[i]);
    }
    double rms = sqrt(power / (length / 2));
    XCTAssertEqualWithAccuracy(20 * log10(rms / (0.5 / sqrt(2))), 0, 0.01);
    free(left);
    free(right);
    free(feed);
}

- (void)testItRefusesNoChannelsAndNoRate {
    XCTAssertTrue(VibeResamplerCreate(44100, 48000, 0) == NULL);
    XCTAssertTrue(VibeResamplerCreate(0, 48000, 2) == NULL);
    XCTAssertTrue(VibeResamplerCreate(44100, 0, 2) == NULL);
}

@end
