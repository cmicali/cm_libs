//
//  Metadata.mm
//
//  Roots a metadata cache of its own and tags a WAV with a title and a PNG
//  picture through TagLib's own writer. Loads the WAV through the cache, into
//  a holder of its own, as an app's row is. Reads the title back, the
//  picture's bytes through the artwork's extractor, and waits for the row
//  thumbnail. Objective-C++, since TagLib's writer is C++.
//

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AudioTrackMetadataCache.h"
#import "AudioTrackMetadataInternal.h"
#import "NSURL+Hash.h"
#import "PlatformImage.h"

#include <attachedpictureframe.h>
#include <id3v2tag.h>
#include <wavfile.h>

static BOOL Fail(const char *what) {
    fprintf(stderr, "consumer: %s\n", what);
    return NO;
}

// Runs main's loop until done says so, for at most ten seconds.
static BOOL Spin(BOOL (^done)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done() && deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return done();
}

// A PNG of one opaque color, side x side.
static NSData *SolidPNG(size_t side) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, side, side, 8, 0, space,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGContextSetRGBFillColor(context, 0.2, 0.5, 0.8, 1);
    CGContextFillRect(context, CGRectMake(0, 0, side, side));
    CGImageRef image = CGBitmapContextCreateImage(context);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
            (__bridge CFMutableDataRef)data, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

// The consumer's own item: the whole of one file, and the metadata the cache
// installs, checked and stored under the item's own monitor.
@interface ConsumerMetadataTrack : NSObject <AudioTrackMetadataHolder>
@property (atomic, strong, nullable, readwrite) AudioTrackMetadata *metadata;
- (instancetype)initWithURL:(NSURL *)url;
@end

@implementation ConsumerMetadataTrack

@synthesize url = _url;

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        _url = [url copy];
    }
    return self;
}

- (NSUInteger)cueStart {
    return 0;
}

- (NSUInteger)cueEnd {
    return 0;
}

- (NSString *)sourceKey {
    return self.url.path;
}

- (NSString *)cacheKey {
    return self.url.cacheKey;
}

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

- (BOOL)deliverIfMetadataStillInstalled:(AudioTrackMetadata *)metadata usingBlock:(NS_NOESCAPE dispatch_block_t)delivery {
    @synchronized (self) {
        if (self.metadata != metadata) {
            return NO;
        }
        delivery();
        return YES;
    }
}

@end

@interface ConsumerMetadataDelegate : NSObject <AudioTrackMetadataCacheDelegate>
@property (atomic) NSUInteger deliveries;
@end

@implementation ConsumerMetadataDelegate
- (void)didLoadMetadata:(id<AudioTrackMetadataHolder>)track {
    self.deliveries++;
}
@end

FOUNDATION_EXTERN BOOL ConsumerLoadsMetadata(void);

BOOL ConsumerLoadsMetadata(void) {
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
                             isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil
                                                      error:NULL]) {
        return Fail("could not make the metadata test's directory");
    }
    // A second of 16-bit mono silence at 8 kHz, in a canonical WAV.
    NSMutableData *wav = [NSMutableData dataWithBytes:"RIFF" length:4];
    uint32_t chunk = 36 + 16000, fmtSize = 16, rate = 8000, byteRate = 16000, dataSize = 16000;
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
    [wav increaseLengthBy:dataSize];
    NSURL *url = [root URLByAppendingPathComponent:@"tagged.wav"];
    NSData *picture = SolidPNG(300);
    BOOL saved = [wav writeToURL:url atomically:YES];
    if (saved) {
        TagLib::RIFF::WAV::File file(url.fileSystemRepresentation);
        file.ID3v2Tag()->setTitle(TagLib::String("Consumer", TagLib::String::UTF8));
        auto frame = new TagLib::ID3v2::AttachedPictureFrame();
        frame->setMimeType("image/png");
        frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
        frame->setPicture(TagLib::ByteVector((const char *)picture.bytes, (unsigned int)picture.length));
        file.ID3v2Tag()->addFrame(frame);
        saved = file.save(TagLib::RIFF::WAV::File::ID3v2);
    }

    BOOL holds = NO;
    if (!saved) {
        Fail("could not write and tag the WAV");
    }
    else {
        AudioTrackMetadataCache *cache = [[AudioTrackMetadataCache alloc]
                initWithRootPath:[root URLByAppendingPathComponent:@"cache"].path];
        ConsumerMetadataDelegate *delegate = [[ConsumerMetadataDelegate alloc] init];
        cache.delegate = delegate;
        ConsumerMetadataTrack *track = [[ConsumerMetadataTrack alloc] initWithURL:url];
        [cache loadMetadataNow:track];
        NSData *art = nil;
        __block VibeImage *thumbnail = nil;
        if (!Spin(^BOOL { return delegate.deliveries > 0; })) {
            Fail("the metadata cache delivered nothing");
        }
        else if (!track.metadata.parsedOK || ![track.metadata.title isEqualToString:@"Consumer"]) {
            Fail("the metadata cache did not read the tagged title");
        }
        else if (VibeTagLibArtExtractor()(url.path, &art) != VibeEmbeddedArtExtractionFoundArt
                 || ![art isEqualToData:picture]) {
            Fail("the artwork's extractor did not read the picture's bytes");
        }
        else if (!Spin(^BOOL { return (thumbnail = track.metadata.cachedThumbnail) != nil; })) {
            Fail("the row thumbnail never decoded");
        }
        else if (thumbnail.size.width <= 0 || thumbnail.size.width > 128 || thumbnail.size.height > 128) {
            Fail("the row thumbnail is not at most 128 px");
        }
        else {
            holds = YES;
        }
        cache.delegate = nil;
    }
    [NSFileManager.defaultManager removeItemAtURL:root error:NULL];
    return holds;
}
