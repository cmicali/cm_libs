//
//  NSURLEmptinessTests.m
//
//  An empty file or a directory is empty. A file with bytes, a missing file
//  and a URL that is not a file are not.
//

#import <XCTest/XCTest.h>
#import "NSURL+Emptiness.h"

@interface NSURLEmptinessTests : XCTestCase
@end

@implementation NSURLEmptinessTests {
    NSURL *_dir;
}

- (void)setUp {
    _dir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"vibe-emptiness-%@", NSUUID.UUID.UUIDString]]];
    [NSFileManager.defaultManager createDirectoryAtURL:_dir withIntermediateDirectories:YES
                                            attributes:nil error:NULL];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtURL:_dir error:NULL];
}

- (NSURL *)fileNamed:(NSString *)name holding:(NSData *)data {
    NSURL *url = [_dir URLByAppendingPathComponent:name];
    [data writeToURL:url atomically:YES];
    return url;
}

- (void)testAnEmptyFileAndADirectoryAreEmpty {
    XCTAssertTrue([self fileNamed:@"empty.mp3" holding:[NSData data]].isEmptyOrDirectory);
    XCTAssertTrue(_dir.isEmptyOrDirectory);
}

- (void)testAFileWithBytesIsNot {
    NSData *bytes = [@"audio" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertFalse([self fileNamed:@"full.mp3" holding:bytes].isEmptyOrDirectory);
}

- (void)testAnUnstattableURLIsNot {
    XCTAssertFalse([_dir URLByAppendingPathComponent:@"missing.mp3"].isEmptyOrDirectory,
                   @"the open reports why");
    XCTAssertFalse([NSURL URLWithString:@"https://example.com/a.mp3"].isEmptyOrDirectory);
}

@end
