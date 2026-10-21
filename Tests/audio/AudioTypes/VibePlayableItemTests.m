//
// The playable-item protocol's helpers, over an item that is not Vibe's row.
//

#import <XCTest/XCTest.h>

#import "VibePlayableItem.h"

// Any object may adopt the protocol.
@interface PlainItem : NSObject <VibePlayableItem>
@property (copy) NSURL *url;
@property NSUInteger cueStart;
@property NSUInteger cueEnd;
@end

@implementation PlainItem

+ (instancetype)itemAtPath:(NSString *)path start:(NSUInteger)start end:(NSUInteger)end {
    PlainItem *item = [PlainItem new];
    item.url = [NSURL fileURLWithPath:path];
    item.cueStart = start;
    item.cueEnd = end;
    return item;
}

- (NSString *)sourceKey {
    return VibeKeyByAppendingCueWindow(self.url.path, self.cueStart, self.cueEnd);
}

- (NSString *)cacheKey {
    return nil;
}

@end

@interface VibePlayableItemTests : XCTestCase
@end

@implementation VibePlayableItemTests

- (void)testAWholeFileKeepsItsKey {
    XCTAssertEqualObjects(VibeKeyByAppendingCueWindow(@"key", 0, 0), @"key");
    XCTAssertNil(VibeKeyByAppendingCueWindow(nil, 75, 150));
}

- (void)testAWindowAppendsItsFrames {
    XCTAssertEqualObjects(VibeKeyByAppendingCueWindow(@"key", 75, 150), @"key#75-150");
    XCTAssertEqualObjects(VibeKeyByAppendingCueWindow(@"key", 75, 0), @"key#75-0");
    XCTAssertEqualObjects([PlainItem itemAtPath:@"/a.flac" start:0 end:75].sourceKey, @"/a.flac#0-75");
}

- (void)testOnlyTheNextWindowOfTheSameFileFollowsContiguously {
    PlainItem *first = [PlainItem itemAtPath:@"/a.flac" start:0 end:75];
    XCTAssertTrue(VibePlayableItemIsFollowedContiguouslyBy(first, [PlainItem itemAtPath:@"/a.flac" start:75 end:150]));
    XCTAssertFalse(VibePlayableItemIsFollowedContiguouslyBy(first, [PlainItem itemAtPath:@"/b.flac" start:75 end:150]));
    XCTAssertFalse(VibePlayableItemIsFollowedContiguouslyBy(first, [PlainItem itemAtPath:@"/a.flac" start:76 end:150]));
    XCTAssertFalse(VibePlayableItemIsFollowedContiguouslyBy([PlainItem itemAtPath:@"/a.flac" start:0 end:0],
                                                            [PlainItem itemAtPath:@"/a.flac" start:0 end:75]));
    XCTAssertFalse(VibePlayableItemIsFollowedContiguouslyBy(first, nil));
    XCTAssertFalse(VibePlayableItemIsFollowedContiguouslyBy(nil, first));
}

@end
