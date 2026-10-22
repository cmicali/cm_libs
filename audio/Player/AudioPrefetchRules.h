//
//  AudioPrefetchRules.h
//  Vibe
//

#import <Foundation/Foundation.h>

#import "FadeMath.h"

typedef NS_ENUM(NSInteger, VibeAudioPrefetchRetirementPoint) {
    VibeAudioPrefetchAtPlaySubmission = 0,
    VibeAudioPrefetchAtPlaySettlement,
    VibeAudioPrefetchAtAbandonment,
};

typedef NS_ENUM(NSInteger, VibeAudioPrefetchDisposition) {
    VibeAudioPrefetchDispositionClear = 0,
    VibeAudioPrefetchDispositionReuseParked,
    VibeAudioPrefetchDispositionJoinPrefetchClaim,
    VibeAudioPrefetchDispositionJoinPlaybackClaim,
    VibeAudioPrefetchDispositionSuppressBehindPlayback,
    VibeAudioPrefetchDispositionStartClaim,
};

// The prefetch request's lifecycle: a late callback for a superseded request
// changes nothing, and a prefetch of another track requested while playback
// is still opening is retained but suppressed until the play's success
// resumes it. Tracks are compared by sourceKey, so another window of the file
// being opened is another track.
typedef NS_OPTIONS(NSUInteger, VibeAudioPrefetchRequestAction) {
    VibeAudioPrefetchRequestActionNone = 0,
    VibeAudioPrefetchRequestActionResume = 1 << 0,
};

typedef struct {
    uint64_t nextRequestIdentifier;
    uint64_t currentRequestIdentifier;
    BOOL requestActive;
    BOOL suppressedBehindPlayback;
} VibeAudioPrefetchRequestState;

typedef struct {
    VibeAudioPrefetchRequestState state;
    VibeAudioPrefetchRequestAction action;
} VibeAudioPrefetchRequestTransition;

static inline VibeAudioPrefetchRequestState
VibeAudioPrefetchRequestStateMake(void) {
    VibeAudioPrefetchRequestState state = {0};
    return state;
}

static inline VibeAudioPrefetchRequestTransition
VibeAudioPrefetchRequestTransitionMake(
        VibeAudioPrefetchRequestState state,
        VibeAudioPrefetchRequestAction action) {
    VibeAudioPrefetchRequestTransition transition = {state, action};
    return transition;
}

static inline VibeAudioPrefetchRequestTransition
VibeAudioPrefetchRequestBegin(VibeAudioPrefetchRequestState state) {
    state.nextRequestIdentifier++;
    if (state.nextRequestIdentifier == 0) {
        state.nextRequestIdentifier++;
    }
    state.currentRequestIdentifier = state.nextRequestIdentifier;
    state.requestActive = YES;
    state.suppressedBehindPlayback = NO;
    return VibeAudioPrefetchRequestTransitionMake(
            state, VibeAudioPrefetchRequestActionNone);
}

static inline VibeAudioPrefetchRequestTransition
VibeAudioPrefetchRequestSuppressBehindPlayback(
        VibeAudioPrefetchRequestState state,
        uint64_t requestIdentifier) {
    if (state.requestActive && state.currentRequestIdentifier == requestIdentifier) {
        state.suppressedBehindPlayback = YES;
    }
    return VibeAudioPrefetchRequestTransitionMake(
            state, VibeAudioPrefetchRequestActionNone);
}

static inline VibeAudioPrefetchRequestTransition
VibeAudioPrefetchRequestFinish(
        VibeAudioPrefetchRequestState state,
        uint64_t requestIdentifier) {
    if (!state.requestActive || state.currentRequestIdentifier != requestIdentifier) {
        return VibeAudioPrefetchRequestTransitionMake(
                state, VibeAudioPrefetchRequestActionNone);
    }
    state.currentRequestIdentifier = 0;
    state.requestActive = NO;
    state.suppressedBehindPlayback = NO;
    return VibeAudioPrefetchRequestTransitionMake(
            state, VibeAudioPrefetchRequestActionNone);
}

static inline VibeAudioPrefetchRequestTransition
VibeAudioPrefetchRequestPlaybackSucceeded(
        VibeAudioPrefetchRequestState state,
        uint64_t requestIdentifier) {
    if (!state.requestActive || state.currentRequestIdentifier != requestIdentifier) {
        return VibeAudioPrefetchRequestTransitionMake(
                state, VibeAudioPrefetchRequestActionNone);
    }
    if (!state.suppressedBehindPlayback) {
        return VibeAudioPrefetchRequestFinish(state, requestIdentifier);
    }
    state.suppressedBehindPlayback = NO;
    return VibeAudioPrefetchRequestTransitionMake(
            state, VibeAudioPrefetchRequestActionResume);
}

static inline BOOL VibeAudioPrefetchDepthAllowsSuccessor(NSUInteger prefetchDepth) {
    return prefetchDepth > 0;
}

static inline VibeAudioPrefetchDisposition VibeAudioPrefetchDispositionForState(
        NSString *requestedKey,
        NSString *prefetchedKey,
        BOOL prefetchedFileReady,
        BOOL prefetchClaimPresent,
        NSString *pendingPlaybackKey) {
    if (!requestedKey) {
        return VibeAudioPrefetchDispositionClear;
    }
    if (prefetchedKey && [requestedKey isEqualToString:prefetchedKey]) {
        if (prefetchedFileReady) {
            return VibeAudioPrefetchDispositionReuseParked;
        }
        if (prefetchClaimPresent) {
            return VibeAudioPrefetchDispositionJoinPrefetchClaim;
        }
    }
    if (pendingPlaybackKey && [requestedKey isEqualToString:pendingPlaybackKey]) {
        return VibeAudioPrefetchDispositionJoinPlaybackClaim;
    }
    if (pendingPlaybackKey) {
        return VibeAudioPrefetchDispositionSuppressBehindPlayback;
    }
    return VibeAudioPrefetchDispositionStartClaim;
}

static inline BOOL VibeAudioPrefetchShouldRetire(
        VibeAudioPrefetchRetirementPoint point,
        NSString *prefetchedKey,
        NSString *playKey) {
    switch (point) {
        case VibeAudioPrefetchAtPlaySubmission:
            return prefetchedKey && ![prefetchedKey isEqualToString:playKey];
        case VibeAudioPrefetchAtPlaySettlement:
            return [prefetchedKey isEqualToString:playKey];
        case VibeAudioPrefetchAtAbandonment:
            return YES;
    }
    return YES;
}

#pragma mark - Track changes

// The length both sides of a track change ride. The user's crossfade applies
// only to a play replacing an audibly playing track, without `declick`.
// `declick` marks a play that replaces a track with its own audio, such as a
// converted copy. A crossfade would overlap that audio with itself. Everything
// else takes the declick minimum, which is also the floor.
static inline uint64_t VibeIncomingFadeMilliseconds(NSInteger crossfadeMilliseconds,
                                                    BOOL replacingAudibleTrack,
                                                    BOOL declick) {
    if (!replacingAudibleTrack || declick) {
        return kFadeDurationMilliseconds;
    }
    return (uint64_t)MAX(crossfadeMilliseconds, (NSInteger)kFadeDurationMilliseconds);
}

// Gapless arms only at the declick minimum, which an app presents as
// crossfade off; a longer setting crossfades auto-advance instead
// (VibeTrackEndCrossfadeMilliseconds) — except into the next window of the
// same file (VibePlayableItemIsFollowedContiguouslyBy), one recording a
// crossfade would overlap with itself.
static inline BOOL VibeGaplessArmAllowed(NSInteger crossfadeMilliseconds, BOOL continuesTheRecording) {
    return continuesTheRecording || crossfadeMilliseconds <= (NSInteger)kFadeDurationMilliseconds;
}

// The crossfade into the parked successor at a track's end: 0 while it is not
// due, else its length. The setting is held to half of each track, so a short
// one is still heard whichever side it is on (one fading in for longer than
// it lasts never reached full gain), and to what remains, so the outgoing side lands on silence
// before its file ends. Due `lateness` early, the most the drain that notices
// can be late; the outgoing side then reaches silence that much before its
// end. A fade no longer than the declick is no crossfade: the track ends.
static inline uint64_t VibeTrackEndCrossfadeMilliseconds(NSInteger crossfadeMilliseconds, NSTimeInterval remaining,
                                                         NSTimeInterval duration, NSTimeInterval nextDuration,
                                                         NSTimeInterval lateness) {
    double fade = MIN((double)crossfadeMilliseconds / 1000.0, MIN(duration, nextDuration) / 2);
    if (remaining > fade + lateness) {
        return 0;
    }
    uint64_t milliseconds = (uint64_t)llround(MAX(0, MIN(fade, remaining)) * 1000);
    return milliseconds > kFadeDurationMilliseconds ? milliseconds : 0;
}
