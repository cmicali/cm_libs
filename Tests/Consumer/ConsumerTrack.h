//
//  ConsumerTrack.h
//
//  The consumer's own row, as an app's playlist row is: a file whole, or a
//  CUE window of it. The player, the metadata cache, and the waveform cache
//  each take it and hand the same object back. The queue holds it as an
//  opaque entry. A fresh object per row, so two rows of one file stay two.
//

#import <Foundation/Foundation.h>

#import "AudioTrackMetadataHolder.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConsumerTrack : NSObject <AudioTrackMetadataHolder>

@property (atomic, strong, nullable, readonly) AudioTrackMetadata *metadata;

// The whole file.
+ (ConsumerTrack *)withURL:(NSURL *)url;

// A window of the file in CD frames, start inclusive and end exclusive. An end
// of 0 runs to the file's end.
- (instancetype)initWithURL:(NSURL *)url cueStart:(NSUInteger)cueStart cueEnd:(NSUInteger)cueEnd
        NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
