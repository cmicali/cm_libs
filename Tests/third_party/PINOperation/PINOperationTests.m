//
//  PINOperationTests.m
//
//  The vendored PINOperation builds and links on its own: a queue runs every
//  operation it was given.
//

#import <XCTest/XCTest.h>
#import <PINOperation/PINOperation.h>
#import <stdatomic.h>

@interface PINOperationTests : XCTestCase
@end

@implementation PINOperationTests

- (void)testQueueRunsEveryOperation {
    PINOperationQueue *queue = [[PINOperationQueue alloc] initWithMaxConcurrentOperations:2];
    __block atomic_int runs = 0;
    for (int i = 0; i < 8; i++) {
        [queue scheduleOperation:^{
            atomic_fetch_add(&runs, 1);
        }];
    }
    [queue waitUntilAllOperationsAreFinished];
    XCTAssertEqual(atomic_load(&runs), 8);
}

@end
