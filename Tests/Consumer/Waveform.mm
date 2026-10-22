//
//  Waveform.mm
//
//  Summarizes a second of a 1 kHz tone at half scale, fed in blocks as a
//  decode would. Reads its peaks and level back, round-trips it through the
//  archive, and draws it 64 pixels wide as a coverage mask.
//

#import <Foundation/Foundation.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

#include "WaveformRaster.hpp"
#include "WaveformSummary.hpp"

extern "C" BOOL ConsumerWaveformHolds(void);

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
