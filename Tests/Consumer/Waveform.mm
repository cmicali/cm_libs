//
//  Waveform.mm
//
//  Summarizes a second of a 1 kHz tone at half scale, fed in blocks as a
//  decode would. Reads its peaks and level back, round-trips it through the
//  archive and through the cache entry an app files, and draws it 64 pixels
//  wide as a coverage mask. Writes the tone as a WAV, loads it into a summary
//  through the waveform loader, and reads its length and peaks back.
//

#import <Foundation/Foundation.h>
#import "AudioWaveform.h"
#import "AudioWaveformLoader.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

#include "WaveformRaster.hpp"
#include "WaveformSummary.hpp"

extern "C" BOOL ConsumerWaveformHolds(void);
extern "C" BOOL ConsumerLoadsAWaveform(void);

BOOL ConsumerWaveformHolds(void) {
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
    std::unique_ptr<wavecore::Summary> summary = builder.finish(true);
    wavecore::Column whole = summary->column(0, double(frames));
    if (std::fabs(whole.hi - 0.5f) > 0.002f || std::fabs(whole.lo + 0.5f) > 0.002f
            || std::fabs(whole.loudest - 0.5f / std::sqrt(2.0f)) > 0.01f) {
        fprintf(stderr, "consumer: the tone reads %.4f to %.4f, level %.4f\n", whole.lo, whole.hi, whole.loudest);
        return NO;
    }
    std::vector<uint8_t> bytes = summary->encode();
    std::unique_ptr<wavecore::Summary> restored = wavecore::Summary::decode(bytes.data(), bytes.size());
    wavecore::Column back = restored ? restored->column(0, double(frames)) : wavecore::Column();
    if (!restored || back.lo != whole.lo || back.hi != whole.hi) {
        fprintf(stderr, "consumer: the archive of %zu bytes read back %.4f to %.4f\n", bytes.size(), back.lo, back.hi);
        return NO;
    }
    CodableAudioWaveform *entry = [[CodableAudioWaveform alloc] initWithWaveform:std::move(restored)];
    entry.results = @{@"tone": @1000};
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:NO error:NULL];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archived error:NULL];
    unarchiver.requiresSecureCoding = NO;
    CodableAudioWaveform *filed = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    if (!filed || filed.waveform->column(0, double(frames)).hi != whole.hi || ![filed.results isEqual:entry.results]) {
        fprintf(stderr, "consumer: the cache entry of %lu bytes did not read back\n", (unsigned long)archived.length);
        return NO;
    }

    // Each pixel's extent is its columns' by their shares, the two steps
    // crossfaded, drawn centred on a 32-row column.
    const int width = 64;
    const int height = 32;
    const double framesPerPixel = double(frames) / width;
    wavecore::StepWindow window = wavecore::StepWindowForPixels(summary->totalFrames(), framesPerPixel, 1, 0, width);
    std::vector<wavecore::Column> columns(window.columnCount());
    for (int p = 0; p < 2; p++) {
        const wavecore::StepPart &part = window.parts[p];
        if (part.count) {
            summary->columns(part.framesPerColumn(), part.first, part.count, columns.data() + window.offset(p));
        }
    }
    std::vector<uint32_t> pixels(size_t(width * height), 0);
    wavecore::ColumnCoverage coverage(height);
    coverage.draw(0, width, pixels.data(), width, [&](int x, auto add) {
        float extent = 0;
        for (int p = 0; p < 2; p++) {
            const wavecore::StepPart &part = window.parts[p];
            wavecore::ForEachColumnShare(x, framesPerPixel / part.framesPerColumn(), part.first, part.count,
                                         [&](size_t i, float share) {
                extent += window.weight(p) * share * columns[window.offset(p) + i].extent();
            });
        }
        add(height / 2.0 * (1 - extent), height / 2.0 * (1 + extent), 1.0f);
    });
    for (int x = 0; x < width; x++) {
        uint32_t edge = pixels[size_t(2 * width + x)];
        uint32_t centre = pixels[size_t(height / 2 * width + x)];
        if (edge != 0 || centre != 0xFFFFFFFFu) {
            fprintf(stderr, "consumer: pixel column %d draws %08x at its edge and %08x at its centre\n", x, edge, centre);
            return NO;
        }
    }
    return YES;
}

// A second of the tone as a 16-bit mono WAV, its bytes written here, loaded
// through the loader as an app's cache would load it.
BOOL ConsumerLoadsAWaveform(void) {
    const uint32_t rate = 44100;
    const uint32_t frames = 44100;
    NSMutableData *wav = [NSMutableData dataWithBytes:"RIFF" length:4];
    uint32_t chunk = 36 + frames * 2, fmtSize = 16, byteRate = rate * 2, dataSize = frames * 2;
    uint16_t pcm = 1, channels = 1, align = 2, bits = 16;
    [wav appendBytes:&chunk length:4];
    [wav appendBytes:"WAVEfmt " length:8];
    [wav appendBytes:&fmtSize length:4];
    [wav appendBytes:&pcm length:2];
    [wav appendBytes:&channels length:2];
    [wav appendBytes:&rate length:4];
    [wav appendBytes:&byteRate length:4];
    [wav appendBytes:&align length:2];
    [wav appendBytes:&bits length:2];
    [wav appendBytes:"data" length:4];
    [wav appendBytes:&dataSize length:4];
    for (uint32_t i = 0; i < frames; i++) {
        int16_t sample = int16_t(std::lround(16384 * std::sin(2 * M_PI * 1000 * double(i) / rate)));
        [wav appendBytes:&sample length:sizeof sample];
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"wav"]];
    [wav writeToFile:path atomically:YES];
    CodableAudioWaveform *loaded = [[[AudioWaveformLoader alloc] init] load:path];
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    AudioWaveform *summary = loaded.waveform;
    wavecore::Column whole = summary ? summary->column(0, double(frames)) : wavecore::Column();
    if (!summary || !summary->isComplete() || summary->totalFrames() != frames || summary->sampleRate() != rate
            || std::fabs(whole.hi - 0.5f) > 0.002f || std::fabs(whole.lo + 0.5f) > 0.002f) {
        fprintf(stderr, "consumer: the loader read %lld frames, %.4f to %.4f\n",
                summary ? (long long)summary->totalFrames() : -1LL, whole.lo, whole.hi);
        return NO;
    }
    return YES;
}
