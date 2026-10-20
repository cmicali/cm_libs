//
//  CommonProbe.m
//
//  Compiles VibeMacros.h alone, with no prefix header and no headermap. The
//  macOS tests and the iOS build both compile it, since the piece is only
//  headers.
//

#import "VibeMacros.h"
#import <CoreAudio/CoreAudioTypes.h>

int VibeCommonProbeAdd(int a, int b) CA_REALTIME_API;

VIBE_REALTIME_CHECKED_BEGIN
int VibeCommonProbeAdd(int a, int b) CA_REALTIME_API {
    return a + b;
}
VIBE_REALTIME_END
