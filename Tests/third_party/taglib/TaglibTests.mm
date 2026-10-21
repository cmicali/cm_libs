//
//  TaglibTests.mm
//
//  The vendored TagLib subset builds and links on its own: a FLAC picture
//  block renders and parses back, and a string converts its case.
//

#import <XCTest/XCTest.h>

#include <flacpicture.h>
#include <tstring.h>

@interface TaglibTests : XCTestCase
@end

@implementation TaglibTests

- (void)testFLACPictureRoundTrips {
    TagLib::FLAC::Picture picture;
    picture.setMimeType("image/png");
    picture.setType(TagLib::FLAC::Picture::FrontCover);
    picture.setData(TagLib::ByteVector("\x89PNG", 4));
    TagLib::FLAC::Picture parsed(picture.render());
    XCTAssertTrue(parsed.mimeType() == "image/png");
    XCTAssertEqual(parsed.type(), TagLib::FLAC::Picture::FrontCover);
    XCTAssertEqual(parsed.data().size(), 4u);
}

- (void)testStringConvertsCase {
    XCTAssertTrue(TagLib::String("Vibe").upper() == "VIBE");
}

@end
