//
//  WaveformStyles.mm
//
//  Summarizes a second of a 1 kHz tone with its bands, fed in blocks as a
//  decode would. Asks the registry for every style it registers, draws each
//  into a layer tree with no window, renders the tree into a bitmap, and
//  reads back that the style drew.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

#import "AudioWaveform.h"
#import "WaveformRenderer.h"
#import "WaveformRendererRegistry.h"

extern "C" BOOL ConsumerWaveformStylesHold(void);

// The pixels of a layer tree whose alpha is not zero, rendered into a
// premultiplied ARGB bitmap of its own size.
static size_t LitPixels(CALayer *layer, size_t width, size_t height) {
    std::vector<uint32_t> pixels(width * height, 0);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedFirst
                                                     | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(space);
    if (!context) {
        return 0;
    }
    [layer renderInContext:context];
    CGContextRelease(context);
    return (size_t)std::count_if(pixels.begin(), pixels.end(), [](uint32_t pixel) { return (pixel >> 24) != 0; });
}

BOOL ConsumerWaveformStylesHold(void) {
    const double rate = 44100;
    const size_t frames = 44100;
    std::vector<float> tone(frames);
    for (size_t i = 0; i < frames; i++) {
        tone[i] = float(0.5 * std::sin(2 * M_PI * 1000 * double(i) / rate));
    }
    wavecore::SummaryBuilder builder(true, int64_t(frames), rate);
    for (size_t at = 0; at < frames; at += 4096) {
        builder.append(tone.data() + at, std::min<size_t>(4096, frames - at));
    }
    std::unique_ptr<AudioWaveform> waveform = builder.finish(true);

    const size_t width = 240;
    const size_t height = 48;
    NSArray<NSString *> *identifiers =
        [WaveformRendererRegistry.availableIdentifiers sortedArrayUsingSelector:@selector(compare:)];
    if (identifiers.count < 9) {
        fprintf(stderr, "consumer: the registry lists %lu styles\n", (unsigned long)identifiers.count);
        return NO;
    }
    for (NSString *identifier in identifiers) {
        CALayer *host = [CALayer layer];
        host.bounds = CGRectMake(0, 0, width, height);
        WaveformRenderer *renderer = [WaveformRendererRegistry rendererForResolvedIdentifier:identifier
                                                                                       layer:host
                                                                                      bounds:host.bounds
                                                                                      isDark:YES];
        [renderer updateWaveform:host.bounds progress:0.5 waveform:waveform.get()];
        [renderer settleMorphImmediately];
        size_t lit = LitPixels(host, width, height);
        if (lit < width * height / 100) {
            fprintf(stderr, "consumer: %s lit %zu of %zu pixels\n", identifier.UTF8String, lit, width * height);
            return NO;
        }
    }
    return YES;
}
