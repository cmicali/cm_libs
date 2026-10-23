//
//  AudioLevelPublisher+Debug.h
//  vibe-libs
//
//  The publisher's counters, for a host's debug report of its levels.
//  Implemented in AudioLevelPublisher+Debug.m.
//

#import "AudioLevelPublisher.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioLevelPublisher (Debug)
- (NSDictionary<NSString *, NSNumber *> *)debugState;
@end

NS_ASSUME_NONNULL_END
