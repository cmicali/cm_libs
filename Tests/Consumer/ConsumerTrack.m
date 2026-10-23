//
//  ConsumerTrack.m
//

#import "ConsumerTrack.h"

#import "AudioTrackMetadata.h"
#import "NSURL+Hash.h"

@interface ConsumerTrack ()
@property (atomic, strong, nullable, readwrite) AudioTrackMetadata *metadata;
@end

@implementation ConsumerTrack {
    NSString *_sourceKey;
}

@synthesize url = _url, cueStart = _cueStart, cueEnd = _cueEnd;

+ (ConsumerTrack *)withURL:(NSURL *)url {
    return [[ConsumerTrack alloc] initWithURL:url cueStart:0 cueEnd:0];
}

- (instancetype)initWithURL:(NSURL *)url cueStart:(NSUInteger)cueStart cueEnd:(NSUInteger)cueEnd {
    if ((self = [super init])) {
        _url = [url copy];
        _cueStart = cueStart;
        _cueEnd = cueEnd;
        // Made once, since the player compares it on paths that run every tick.
        _sourceKey = VibeKeyByAppendingCueWindow(url.path, cueStart, cueEnd) ?: @"";
    }
    return self;
}

- (NSString *)sourceKey {
    return _sourceKey;
}

- (NSString *)cacheKey {
    return self.url.cacheKey;
}

// The check and the store share this row's monitor, which @synchronized makes
// recursive, as the holder protocol asks.
- (BOOL)installMetadataIfUnresolved:(AudioTrackMetadata *)metadata {
    @synchronized (self) {
        AudioTrackMetadata *installed = self.metadata;
        if (installed.parsedOK && [installed.cacheKey isEqualToString:metadata.cacheKey]) {
            return NO;
        }
        self.metadata = metadata;
        return YES;
    }
}

- (BOOL)deliverIfMetadataStillInstalled:(AudioTrackMetadata *)metadata
                             usingBlock:(NS_NOESCAPE dispatch_block_t)delivery {
    @synchronized (self) {
        if (self.metadata != metadata) {
            return NO;
        }
        delivery();
        return YES;
    }
}

@end
