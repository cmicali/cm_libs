//
// Prefetch retirement across play races and abandonment.
//

#import <XCTest/XCTest.h>

#import "AudioPrefetchRules.h"

@interface AudioPrefetchRulesTests : XCTestCase
@end

@implementation AudioPrefetchRulesTests

- (void)testConfiguredPrefetchDepthZeroDisablesTheSuccessor {
    XCTAssertFalse(VibeAudioPrefetchDepthAllowsSuccessor(0));
    XCTAssertTrue(VibeAudioPrefetchDepthAllowsSuccessor(1));
}

- (void)testPlaySubmissionCancelsOnlyAnUnrelatedOldPrefetch {
    XCTAssertTrue(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtPlaySubmission, @"/next.flac", @"/picked.flac"));
    XCTAssertFalse(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtPlaySubmission, @"/picked.flac", @"/picked.flac"));
}

- (void)testSettledPlayRetiresItsSamePathPrefetchRacer {
    XCTAssertTrue(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtPlaySettlement, @"/picked.flac", @"/picked.flac"));
    XCTAssertFalse(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtPlaySettlement, @"/later.flac", @"/picked.flac"));
}

- (void)testStopAndFailureAlwaysRetireTheWholePark {
    XCTAssertTrue(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtAbandonment, @"/next.flac", nil));
    XCTAssertTrue(VibeAudioPrefetchShouldRetire(
            VibeAudioPrefetchAtAbandonment, nil, nil));
}

- (void)testDifferentPathPrefetchIsSuppressedBehindPendingPlayback {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/next.flac", nil, NO, NO,
                                                        @"/picked.flac"),
                   VibeAudioPrefetchDispositionSuppressBehindPlayback);
}

- (void)testSuppressionDoesNotDependOnAnExistingPark {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/next.flac", @"/old.flac",
                                                        YES, YES, @"/picked.flac"),
                   VibeAudioPrefetchDispositionSuppressBehindPlayback);
}

- (void)testSamePathPrefetchJoinsPlaybackClaim {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/picked.flac", nil, NO, NO,
                                                        @"/picked.flac"),
                   VibeAudioPrefetchDispositionJoinPlaybackClaim);
}

- (void)testSamePathInFlightPrefetchJoinsItsClaim {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/next.flac", @"/next.flac",
                                                        NO, YES, nil),
                   VibeAudioPrefetchDispositionJoinPrefetchClaim);
}

- (void)testSamePathParkedFileIsReused {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/next.flac", @"/next.flac",
                                                        YES, NO, nil),
                   VibeAudioPrefetchDispositionReuseParked);
}

- (void)testNilRequestClearsEvenWhilePlaybackIsPending {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(nil, @"/next.flac", YES, NO,
                                                        @"/picked.flac"),
                   VibeAudioPrefetchDispositionClear);
}

- (void)testNewTargetStartsAfterPlaybackSettles {
    XCTAssertEqual(VibeAudioPrefetchDispositionForState(@"/next.flac", nil, NO, NO, nil),
                   VibeAudioPrefetchDispositionStartClaim);
}

- (void)testSuppressedRequestResumesAfterPlaySuccess {
    VibeAudioPrefetchRequestState state = VibeAudioPrefetchRequestStateMake();
    state = VibeAudioPrefetchRequestBegin(state).state;
    uint64_t requestIdentifier = state.currentRequestIdentifier;

    state = VibeAudioPrefetchRequestSuppressBehindPlayback(
            state, requestIdentifier).state;
    XCTAssertTrue(state.suppressedBehindPlayback);

    VibeAudioPrefetchRequestTransition transition =
            VibeAudioPrefetchRequestPlaybackSucceeded(state, requestIdentifier);
    XCTAssertEqual(transition.action, VibeAudioPrefetchRequestActionResume);
    XCTAssertTrue(transition.state.requestActive);
    XCTAssertFalse(transition.state.suppressedBehindPlayback);
}

- (void)testUnsuppressedRequestFinishesOnPlaySuccess {
    VibeAudioPrefetchRequestState state = VibeAudioPrefetchRequestStateMake();
    state = VibeAudioPrefetchRequestBegin(state).state;
    uint64_t requestIdentifier = state.currentRequestIdentifier;

    VibeAudioPrefetchRequestTransition transition =
            VibeAudioPrefetchRequestPlaybackSucceeded(state, requestIdentifier);
    XCTAssertEqual(transition.action, VibeAudioPrefetchRequestActionNone);
    XCTAssertFalse(transition.state.requestActive);
}

- (void)testSuppressedRequestDropsWhenTerminallyRetired {
    VibeAudioPrefetchRequestState state = VibeAudioPrefetchRequestStateMake();
    state = VibeAudioPrefetchRequestBegin(state).state;
    uint64_t requestIdentifier = state.currentRequestIdentifier;
    state = VibeAudioPrefetchRequestSuppressBehindPlayback(
            state, requestIdentifier).state;

    VibeAudioPrefetchRequestTransition transition =
            VibeAudioPrefetchRequestFinish(state, requestIdentifier);
    XCTAssertFalse(transition.state.requestActive);
    XCTAssertFalse(transition.state.suppressedBehindPlayback);
    // Finished is terminal: a repeat of the same identifier changes nothing.
    transition = VibeAudioPrefetchRequestFinish(transition.state, requestIdentifier);
    XCTAssertEqual(transition.action, VibeAudioPrefetchRequestActionNone);
}

- (void)testLaterPrefetchUsesFreshRequestIdentity {
    VibeAudioPrefetchRequestState state = VibeAudioPrefetchRequestStateMake();
    state = VibeAudioPrefetchRequestBegin(state).state;
    uint64_t firstIdentifier = state.currentRequestIdentifier;
    state = VibeAudioPrefetchRequestSuppressBehindPlayback(
            state, firstIdentifier).state;

    state = VibeAudioPrefetchRequestBegin(state).state;
    XCTAssertNotEqual(state.currentRequestIdentifier, firstIdentifier);
    XCTAssertFalse(state.suppressedBehindPlayback);

    // A stale identifier's edges change nothing for the fresh request.
    VibeAudioPrefetchRequestTransition stale =
            VibeAudioPrefetchRequestFinish(state, firstIdentifier);
    XCTAssertTrue(stale.state.requestActive);
    VibeAudioPrefetchRequestTransition current =
            VibeAudioPrefetchRequestFinish(state, state.currentRequestIdentifier);
    XCTAssertFalse(current.state.requestActive);
}

#pragma mark - The track-change fade length

- (void)testReplacingAnAudiblyPlayingTrackTakesTheCrossfadeSetting {
    XCTAssertEqual(VibeIncomingFadeMilliseconds(2000, YES, NO), 2000u);
    XCTAssertEqual(VibeIncomingFadeMilliseconds(500, YES, NO), 500u);
}

- (void)testAPlayWithNothingAudibleTakesTheDeclickMinimum {
    XCTAssertEqual(VibeIncomingFadeMilliseconds(2000, NO, NO), kFadeDurationMilliseconds);
}

// The convert swap replaces a track with its own audio, which a crossfade would only dip.
- (void)testTheDeclickFlagOverridesTheSetting {
    XCTAssertEqual(VibeIncomingFadeMilliseconds(2000, YES, YES), kFadeDurationMilliseconds);
}

- (void)testTheSettingCannotFadeFasterThanTheDeclickMinimum {
    XCTAssertEqual(VibeIncomingFadeMilliseconds(0, YES, NO), kFadeDurationMilliseconds);
    XCTAssertEqual(VibeIncomingFadeMilliseconds(-100, YES, NO), kFadeDurationMilliseconds);
    XCTAssertEqual(VibeIncomingFadeMilliseconds((NSInteger)kFadeDurationMilliseconds, YES, NO),
                   kFadeDurationMilliseconds);
}

// The declick minimum is what the UI presents as crossfade off.
- (void)testGaplessArmsOnlyAtTheDeclickMinimum {
    XCTAssertTrue(VibeGaplessArmAllowed(10, NO));
    XCTAssertTrue(VibeGaplessArmAllowed(0, NO));
    XCTAssertFalse(VibeGaplessArmAllowed(500, NO));
    XCTAssertFalse(VibeGaplessArmAllowed(2000, NO));
}

// The next window of the same file is one recording: a crossfade would
// overlap it with itself.
- (void)testGaplessArmsIntoTheNextWindowOfTheFileWhateverTheCrossfade {
    XCTAssertTrue(VibeGaplessArmAllowed(2000, YES));
    XCTAssertTrue(VibeGaplessArmAllowed(10, YES));
}

#pragma mark - The track-end crossfade

- (void)testTheTrackEndCrossfadeIsDueItsLengthPlusTheLatenessBeforeTheEnd {
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 2.2, 180, 180, 0.1), 0u, @"not yet due");
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 2.05, 180, 180, 0.1), 2000u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(500, 0.59, 180, 180, 0.1), 500u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(500, 0.61, 180, 180, 0), 0u);
}

// A drain later than the lateness, or a seek into the last second: the fade
// is what remains, so the outgoing side still lands on silence at its end.
- (void)testALateTrackEndCrossfadeFadesOverWhatRemains {
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 0.75, 180, 180, 0.1), 750u);
}

// Half of a short track is the most a crossfade takes, so it is still heard.
- (void)testAShortTrackIsCrossfadedOverHalfItsLength {
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(3000, 0.4, 0.8, 180, 0.1), 400u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(3000, 0.6, 0.8, 180, 0.1), 0u, @"not yet due");
}

// A short next track caps it the same way, so it reaches full gain before its
// own track end fades it out.
- (void)testAShortNextTrackIsCrossfadedIntoOverHalfItsLength {
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(10000, 1.5, 300, 3, 0.1), 1500u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(10000, 1.7, 300, 3, 0.1), 0u, @"not yet due");
}

// Off, or nothing left to fade, is the ordinary track end.
- (void)testNoFadeLongerThanTheDeclickIsATrackEndCrossfade {
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds((NSInteger)kFadeDurationMilliseconds, 0.005, 180, 180, 0.1), 0u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 0.005, 180, 180, 0.1), 0u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 0, 180, 180, 0.1), 0u);
    XCTAssertEqual(VibeTrackEndCrossfadeMilliseconds(2000, 0.5, 0.01, 180, 0.1), 0u, @"a track too short to fade");
}

@end
