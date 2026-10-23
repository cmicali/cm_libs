//
//  WaveformView.mm
//
//  Summarizes a second of a 1 kHz tone, lays the mac waveform view out with
//  it under a theme of its own, with no window, renders the view's layer tree
//  into a bitmap, and reads back that the played side and the unplayed side
//  each drew, in different colors.
//

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

#import "AudioWaveform.h"
#import "WaveformView.h"

extern "C" BOOL ConsumerWaveformViewDraws(void);

// A premultiplied ARGB pixel of the bitmap, as 0xAARRGGBB.
static uint32_t PixelAt(const std::vector<uint32_t> &pixels, size_t width, size_t height, size_t x, size_t y) {
    return pixels[(height - 1 - y) * width + x];
}

BOOL ConsumerWaveformViewDraws(void) {
    const double rate = 44100;
    const size_t frames = 44100;
    std::vector<float> tone(frames);
    for (size_t i = 0; i < frames; i++) {
        tone[i] = float(0.5 * std::sin(2 * M_PI * 1000 * double(i) / rate));
    }
    wavecore::SummaryBuilder builder(false, int64_t(frames), rate);
    for (size_t at = 0; at < frames; at += 4096) {
        builder.append(tone.data() + at, std::min<size_t>(4096, frames - at));
    }
    CodableAudioWaveform *summary = [[CodableAudioWaveform alloc] initWithWaveform:builder.finish(true)];

    const size_t width = 240;
    const size_t height = 48;
    WaveformView *view = [[WaveformView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    view.themeProvider = ^WaveformTheme *(BOOL isDark, NSColor *artworkColor) {
        return [WaveformTheme themeForIdentifier:SETTINGS_VALUE_WAVEFORM_THEME_CUSTOM isDark:isDark
                                    artworkColor:artworkColor
                                    customPlayed:NSColor.blueColor
                                  customUnplayed:NSColor.redColor];
    };
    [view setWaveformStyle:@"detailed"];
    [view prepareForWaveformLoad];
    // With no window, nobody can see the view, so the delivery lands settled.
    [view showWaveform:summary];
    view.progress = 0.5;
    [view layoutSubtreeIfNeeded];

    std::vector<uint32_t> pixels(width * height, 0);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedFirst
                                                     | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(space);
    if (!context) {
        return NO;
    }
    [view.layer renderInContext:context];
    CGContextRelease(context);

    uint32_t played = PixelAt(pixels, width, height, width / 4, height / 2);
    uint32_t unplayed = PixelAt(pixels, width, height, width * 3 / 4, height / 2);
    bool playedBlue = (played >> 24) != 0 && (played & 0xFF) > ((played >> 16) & 0xFF);
    bool unplayedRed = (unplayed >> 24) != 0 && ((unplayed >> 16) & 0xFF) > (unplayed & 0xFF);
    if (!playedBlue || !unplayedRed) {
        fprintf(stderr, "consumer: the waveform view drew %08x played and %08x unplayed\n", played, unplayed);
        return NO;
    }
    return YES;
}
