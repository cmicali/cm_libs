//
//  ShareLinks.m
//
//  Serves a temporary directory through the fake web server, under a plain
//  HTTP transfer client of its own. Downloads a file from it and reads a
//  range of it, and checks both against the file's bytes.
//

#import <Foundation/Foundation.h>

#import "HTTPTransferClient.h"
#import "VibeFakeHTTP.h"

FOUNDATION_EXTERN BOOL ConsumerFetchesFromTheFakeHost(void);

BOOL ConsumerFetchesFromTheFakeHost(void) {
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                          NSUUID.UUID.UUIDString] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:NULL];
    NSMutableData *bytes = [NSMutableData dataWithLength:300 * 1024];
    uint8_t *raw = bytes.mutableBytes;
    for (NSUInteger i = 0; i < bytes.length; i++) {
        raw[i] = (uint8_t)(i * 7 + i / 251);
    }
    [bytes writeToURL:[root URLByAppendingPathComponent:@"song.mp3"] atomically:NO];
    NSURL *part = [root URLByAppendingPathComponent:@"song.part"];

    HTTPTransferClient *client = [[HTTPTransferClient alloc]
            initWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    [VibeFakeHTTP installWithDirectory:root transferSeconds:0 client:client];
    NSURL *song = [NSURL URLWithString:@"https://fake.vibe.test/song.mp3"];

    __block NSError *downloadError = nil;
    dispatch_semaphore_t downloaded = dispatch_semaphore_create(0);
    [client downloadTarget:song toURL:part progress:nil completion:^(NSDictionary *metadata, NSError *error) {
        downloadError = error;
        dispatch_semaphore_signal(downloaded);
    }];
    __block NSData *range = nil;
    dispatch_semaphore_t read = dispatch_semaphore_create(0);
    [client readTarget:song offset:1000 length:64 completion:^(NSData *data, NSDictionary *metadata, NSError *error) {
        range = data;
        dispatch_semaphore_signal(read);
    }];
    long timedOut = dispatch_semaphore_wait(downloaded, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC))
                  | dispatch_semaphore_wait(read, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    NSData *fetched = [NSData dataWithContentsOfURL:part];
    [VibeFakeHTTP uninstallFromClient:client];
    [NSFileManager.defaultManager removeItemAtURL:root error:NULL];

    BOOL whole = [fetched isEqualToData:bytes];
    BOOL ranged = [range isEqualToData:[bytes subdataWithRange:NSMakeRange(1000, 64)]];
    if (timedOut || downloadError || !whole || !ranged) {
        fprintf(stderr, "consumer: the fake host's download %s (%s), its range %s\n",
                whole ? "matched" : "did not match", downloadError.description.UTF8String ?: "no error",
                ranged ? "matched" : "did not match");
        return NO;
    }
    return YES;
}
