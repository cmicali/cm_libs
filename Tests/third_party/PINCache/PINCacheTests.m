//
//  PINCacheTests.m
//
//  The vendored PINCache builds and links on its own: an object written to a
//  cache in a temporary folder reads back.
//

#import <XCTest/XCTest.h>
#import <PINCache/PINCache.h>

@interface PINCacheTests : XCTestCase
@end

@implementation PINCacheTests

- (void)testObjectReadsBack {
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    PINCache *cache = [[PINCache alloc] initWithName:@"probe" rootPath:root];
    [cache setObject:@"value" forKey:@"key"];
    XCTAssertEqualObjects([cache objectForKey:@"key"], @"value");
    [cache removeAllObjects];
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
}

@end
