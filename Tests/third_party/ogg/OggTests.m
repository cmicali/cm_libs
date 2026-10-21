//
//  OggTests.m
//
//  The vendored libogg builds and links on its own: its page reader finds no
//  page in bytes that hold none.
//

#import <XCTest/XCTest.h>

#include <ogg/ogg.h>

@interface OggTests : XCTestCase
@end

@implementation OggTests

- (void)testFindsNoPageInJunk {
    ogg_sync_state sync;
    ogg_sync_init(&sync);
    char *buffer = ogg_sync_buffer(&sync, 64);
    memset(buffer, 0, 64);
    ogg_sync_wrote(&sync, 64);
    ogg_page page;
    XCTAssertLessThanOrEqual(ogg_sync_pageout(&sync, &page), 0);
    ogg_sync_clear(&sync);
}

@end
