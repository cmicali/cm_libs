//
//  AppOpening.m
//
//  Sends two batches of one open before launch and a third after, as Launch
//  Services may split one open. The coalescer's sink begins one request on
//  the coordinator for each drain, as an app's funnel does. The expansions
//  finish in reverse order, and the rows still arrive as one replacing open
//  and then one append, in the order the batches came.
//

#import <Foundation/Foundation.h>

#import "OpenBurstCoalescer.h"
#import "OpenRequestCoordinator.h"

FOUNDATION_EXTERN BOOL ConsumerOrdersASplitOpen(void);

BOOL ConsumerOrdersASplitOpen(void) {
    OpenRequestCoordinator *coordinator = [OpenRequestCoordinator new];
    NSMutableArray<NSString *> *delivered = [NSMutableArray array];
    NSMutableArray<OpenRequestToken *> *tokens = [NSMutableArray array];
    NSMutableArray<NSArray<NSURL *> *> *batches = [NSMutableArray array];
    // The quiet period never elapses, so every batch belongs to one burst.
    OpenBurstCoalescer *coalescer = [[OpenBurstCoalescer alloc]
            initWithQuietPeriod:0.3
                      scheduler:^(NSTimeInterval delay, dispatch_block_t block) {}
                           sink:^(NSArray<NSURL *> *urls, BOOL append) {
                               [batches addObject:urls];
                               [tokens addObject:[coordinator beginRequestAppending:append
                                                                           delivery:^(NSArray *rows, NSUInteger folderCount, BOOL appending) {
                                   NSArray *names = [rows valueForKey:@"lastPathComponent"];
                                   [delivered addObject:[NSString stringWithFormat:@"%@ %@",
                                                         appending ? @"append" : @"replace",
                                                         [names componentsJoinedByString:@","]]];
                               }]];
                           }];
    NSURL *(^file)(NSString *) = ^NSURL *(NSString *name) {
        return [NSURL fileURLWithPath:[@"/consumer/opens" stringByAppendingPathComponent:name]];
    };
    [coalescer openBurstURLs:@[file(@"a.wav"), file(@"b.wav")]];
    [coalescer openBurstURLs:@[file(@"c.wav")]];
    BOOL drained = [coalescer startAndDrainQueue];
    [coalescer openBurstURLs:@[file(@"d.wav")]];
    // Each expansion hands its batch back as its rows, the later one first.
    for (NSInteger i = (NSInteger)tokens.count - 1; i >= 0; i--) {
        [coordinator finishRequest:tokens[(NSUInteger)i] rows:batches[(NSUInteger)i] folderCount:0];
    }
    NSArray *expected = @[@"replace a.wav,b.wav,c.wav", @"append d.wav"];
    if (!drained || ![delivered isEqualToArray:expected]) {
        fprintf(stderr, "consumer: a split open delivered %s\n", delivered.description.UTF8String);
        return NO;
    }
    return YES;
}
