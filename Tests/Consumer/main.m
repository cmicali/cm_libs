//
//  main.m
//
//  Plays a ramp through the varispeed at zero pitch and checks it comes back
//  exactly, then renders off zero. Round-trips a color through its hex form.
//  Exits 0 when all three hold.
//

#import <Foundation/Foundation.h>
#import "AudioVarispeed.h"
#import "PlatformColor.h"

enum { kFrames = 512 };

static OSStatus Ramp(void *context, const AudioTimeStamp *stamp, UInt32 frames, AudioBufferList *into) CA_REALTIME_API {
    uint64_t *next = context;
    for (UInt32 c = 0; c < into->mNumberBuffers; c++) {
        float *out = into->mBuffers[c].mData;
        for (UInt32 n = 0; n < frames; n++) {
            out[n] = (float)((*next + n) % 1024) / 1024.0f;
        }
    }
    *next += frames;
    return noErr;
}

int main(void) {
    VibeVarispeed *stage = VibeVarispeedCreate(2, kFrames);
    if (!stage) {
        fprintf(stderr, "consumer: no stage\n");
        return 1;
    }
    float left[kFrames], right[kFrames];
    VibeStereoBufferList out = { 2, {{1, sizeof left, left}, {1, sizeof right, right}} };
    AudioTimeStamp stamp = {0};
    uint64_t next = 0;
    for (int slice = 0; slice < 8; slice++) {
        uint64_t first = next;
        VibeVarispeedRender(stage, Ramp, &next, &stamp, kFrames, (AudioBufferList *)&out);
        for (UInt32 n = 0; n < kFrames; n++) {
            float want = (float)((first + n) % 1024) / 1024.0f;
            if (left[n] != want || right[n] != want) {
                fprintf(stderr, "consumer: frame %llu is %f, not %f\n", first + n, left[n], want);
                return 1;
            }
        }
    }
    VibeVarispeedTable *replaced = NULL;
    if (!VibeVarispeedSetPitch(stage, 2.0, &replaced)) {
        fprintf(stderr, "consumer: no table\n");
        return 1;
    }
    for (int slice = 0; slice < 8; slice++) {
        VibeVarispeedRender(stage, Ramp, &next, &stamp, kFrames, (AudioBufferList *)&out);
    }
    if (replaced) {
        VibeVarispeedRetire(stage, replaced);
    }
    BOOL engaged = VibeVarispeedEngaged(stage);
    VibeVarispeedFree(stage);
    if (!engaged) {
        fprintf(stderr, "consumer: the converter never joined\n");
        return 1;
    }
    NSString *hex = VibeHexStringFromColor(VibeColorFromHexString(@"#12345678"));
    if (![hex isEqualToString:@"#12345678"]) {
        fprintf(stderr, "consumer: the color came back as %s\n", hex.UTF8String);
        return 1;
    }
    printf("consumer OK\n");
    return 0;
}
