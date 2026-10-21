//
// The bounded disk cache: a store under a root of the caller's, with the
// shared byte and age limits, and its usage on disk.
//

#import <XCTest/XCTest.h>

#import "PINCache+VibeAudioCache.h"

@interface PINCacheVibeAudioCacheTests : XCTestCase
@end

@implementation PINCacheVibeAudioCacheTests {
    NSString *_root;
}

- (void)setUp {
    [super setUp];
    _root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtPath:_root error:nil];
    [super tearDown];
}

- (void)testAStoreUnderARootHasTheSharedLimits {
    PINCache *cache = [PINCache audioCacheWithName:@"limits" rootPath:_root];
    XCTAssertEqual(cache.diskCache.byteLimit, 1024u * 1024u * 1024u);
    XCTAssertEqual(cache.diskCache.ageLimit, 180.0 * 24 * 60 * 60);
    XCTAssertTrue([cache.diskCache.cacheURL.path hasPrefix:_root], @"%@", cache.diskCache.cacheURL.path);
}

- (void)testUsageCountsEveryEntryAndItsBytesOnMain {
    PINCache *cache = [PINCache audioCacheWithName:@"usage" rootPath:_root];
    [cache.diskCache setObject:[NSMutableData dataWithLength:1000] forKey:@"one"];
    [cache.diskCache setObject:[NSMutableData dataWithLength:3000] forKey:@"two"];
    XCTestExpectation *counted = [self expectationWithDescription:@"counted"];
    [cache audioDiskUsageWithCompletion:^(NSUInteger fileCount, unsigned long long totalBytes) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqual(fileCount, 2u);
        XCTAssertGreaterThanOrEqual(totalBytes, 4000u);
        [counted fulfill];
    }];
    [self waitForExpectations:@[counted] timeout:VIBE_TEST_HANG_TIMEOUT];
}

@end
