//
//  FileLoading.m
//
//  Opens a temporary file through the file loader, with a handle of its own.
//  Then installs the fake cloud, opens a file it makes a placeholder, and
//  cancels the open while the download is in flight. The claim and the
//  transfer let go, the loading row goes away, and nothing is delivered or
//  kept.
//

#import <Foundation/Foundation.h>

#import "AudioFileMaterializationCoordinator+Debug.h"
#import "CloudTransferRegistry.h"
#import "VibeFakeCloud.h"

FOUNDATION_EXTERN BOOL ConsumerOpensAFile(void);
FOUNDATION_EXTERN BOOL ConsumerCancelsACloudOpen(void);

// The handle the file loader serves. It reads no stream, so it ignores the
// hold.
@interface ConsumerFile : NSObject <ServedFileHandle>
@property (nonatomic, strong) NSURL *url;
@end

@implementation ConsumerFile
- (void)holdStream {
}
@end

static BOOL Settles(BOOL (^done)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done() && deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return done();
}

static NSURL *TemporaryFile(NSString *name) {
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
                                            attributes:nil error:NULL];
    NSURL *url = [directory URLByAppendingPathComponent:name];
    [[NSData dataWithBytes:"bytes" length:5] writeToURL:url atomically:YES];
    return url;
}

// No claim, waiter, or handle run left on the app's one coordinator.
static BOOL CoordinatorIsIdle(void) {
    NSDictionary<NSString *, NSNumber *> *state = AudioFileMaterializationCoordinator.sharedCoordinator.debugState;
    return state[@"claims"].unsignedIntegerValue == 0 && state[@"waiters"].unsignedIntegerValue == 0
            && state[@"handleRuns"].unsignedIntegerValue == 0;
}

BOOL ConsumerOpensAFile(void) {
    NSURL *track = TemporaryFile(@"track.bin");
    __block ConsumerFile *served = nil;
    __block NSError *openError = nil;
    __block BOOL opened = NO;
    [AudioFileMaterializationCoordinator.sharedCoordinator openURL:track
            purpose:VibeAudioFileOpenPurposePlayback
             opener:^id<ServedFileHandle>(NSURL *url, BOOL (^interrupted)(void), NSError **error) {
        ConsumerFile *file = [[ConsumerFile alloc] init];
        file.url = url;
        return file;
    } completionQueue:dispatch_get_main_queue() onDataless:nil
         completion:^(id<ServedFileHandle> file, NSError *error, NSTimeInterval elapsed) {
        served = (ConsumerFile *)file;
        openError = error;
        opened = YES;
    }];
    BOOL held = Settles(^BOOL { return opened; }) && [served.url isEqual:track];
    [NSFileManager.defaultManager removeItemAtURL:track.URLByDeletingLastPathComponent error:NULL];
    if (!held) {
        fprintf(stderr, "consumer: the loader served %s (%s)\n", served.url.path.UTF8String,
                openError.localizedDescription.UTF8String);
        return NO;
    }
    return YES;
}

// Every file reads as a placeholder whose download takes 30 seconds. The open
// reports the file dataless, and the fake's transfer starts. The cancel stops
// it there: the opener is never called, nothing is delivered, the fake counts
// one more cancel, and the claim, the row's loading entry, and the token go.
BOOL ConsumerCancelsACloudOpen(void) {
    AudioFileMaterializationCoordinator *coordinator = AudioFileMaterializationCoordinator.sharedCoordinator;
    if (!Settles(^BOOL { return CoordinatorIsIdle(); })) {
        fprintf(stderr, "consumer: the coordinator was busy before the cloud open: %s\n",
                coordinator.debugState.description.UTF8String);
        return NO;
    }
    NSURL *url = TemporaryFile(@"cloud.wav");
    [VibeFakeCloud installWithTransferSeconds:30 datalessPercent:100];
    [VibeFakeCloud setUniformDurations:YES];
    NSUInteger cancelled = [VibeFakeCloud.statistics[@"cancelled"] unsignedIntegerValue];
    CloudTransferRegistry *registry = CloudTransferRegistry.sharedRegistry;
    __block BOOL dataless = NO, delivered = NO, opened = NO;
    __weak AudioFileOpenToken *released = nil;
    BOOL inFlight = NO;
    @autoreleasepool {
        AudioFileOpenToken *token = [coordinator openURL:url purpose:VibeAudioFileOpenPurposePlayback
                opener:^id<ServedFileHandle>(NSURL *file, BOOL (^interrupted)(void), NSError **error) {
            opened = YES;
            return nil;
        } completionQueue:dispatch_get_main_queue() onDataless:^{
            dataless = YES;
        } completion:^(id<ServedFileHandle> file, NSError *error, NSTimeInterval elapsed) {
            delivered = YES;
        }];
        released = token;
        inFlight = Settles(^BOOL {
            return dataless && [registry isTransferringURL:url]
                    && [VibeFakeCloud.statistics[@"executing"] unsignedIntegerValue] == 1;
        });
        [token cancel];
    }
    BOOL letGo = Settles(^BOOL {
        return CoordinatorIsIdle() && ![registry isTransferringURL:url] && released == nil
                && [VibeFakeCloud.statistics[@"executing"] unsignedIntegerValue] == 0
                && [VibeFakeCloud.statistics[@"cancelled"] unsignedIntegerValue] == cancelled + 1;
    });
    // A window for a forbidden delivery.
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    NSDictionary *state = coordinator.debugState;
    NSDictionary *cloud = VibeFakeCloud.statistics;
    [VibeFakeCloud uninstall];
    [NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:NULL];
    if (!inFlight || !letGo || delivered || opened) {
        fprintf(stderr, "consumer: the cloud open was in flight %d, let go %d, delivered %d, and opened %d, "
                "with the token %s, the coordinator at %s, and the fake cloud at %s\n", inFlight, letGo,
                delivered, opened, released ? "kept" : "released", state.description.UTF8String,
                cloud.description.UTF8String);
        return NO;
    }
    return YES;
}
