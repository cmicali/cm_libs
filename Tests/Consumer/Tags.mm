//
//  Tags.mm
//
//  Tags a WAV with an ID3v2 title and a picture through TagLib's own writer.
//  Reads the title back through media/Tags' wrapper, from the file on disk.
//  Reads the picture's bytes back through a byte-range reader, as an app
//  reads a file whose bytes are on a server. Objective-C++, since the
//  wrapper's header is C++.
//

#import <Foundation/Foundation.h>
#import "TagLibAudioFile.h"

#include <attachedpictureframe.h>
#include <id3v2tag.h>
#include <wavfile.h>

static BOOL Fail(const char *what) {
    fprintf(stderr, "consumer: %s\n", what);
    return NO;
}

FOUNDATION_EXTERN BOOL ConsumerReadsTags(void);

BOOL ConsumerReadsTags(void) {
    // A second of 16-bit mono silence at 8 kHz, in a canonical WAV.
    NSMutableData *wav = [NSMutableData dataWithBytes:"RIFF" length:4];
    uint32_t chunk = 36 + 16000, fmtSize = 16, rate = 8000, byteRate = 16000, dataSize = 16000;
    uint16_t pcm = 1, channels = 1, align = 2, bits = 16;
    [wav appendBytes:&chunk length:4];
    [wav appendBytes:"WAVEfmt " length:8];
    [wav appendBytes:&fmtSize length:4];
    [wav appendBytes:&pcm length:2];
    [wav appendBytes:&channels length:2];
    [wav appendBytes:&rate length:4];
    [wav appendBytes:&byteRate length:4];
    [wav appendBytes:&align length:2];
    [wav appendBytes:&bits length:2];
    [wav appendBytes:"data" length:4];
    [wav appendBytes:&dataSize length:4];
    [wav increaseLengthBy:dataSize];
    NSString *path = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"wav"]];
    if (![wav writeToFile:path atomically:YES]) {
        return Fail("could not write the WAV to tag");
    }

    const char picture[] = "\x89PNG\r\n\x1A\n not a real image";
    {
        TagLib::RIFF::WAV::File file(path.fileSystemRepresentation);
        file.ID3v2Tag()->setTitle(TagLib::String("Consumer", TagLib::String::UTF8));
        auto frame = new TagLib::ID3v2::AttachedPictureFrame();
        frame->setMimeType("image/png");
        frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
        frame->setPicture(TagLib::ByteVector(picture, sizeof picture - 1));
        file.ID3v2Tag()->addFrame(frame);
        if (!file.save(TagLib::RIFF::WAV::File::ID3v2)) {
            [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
            return Fail("TagLib did not save the tag");
        }
    }

    BOOL read = NO;
    {
        TagLibAudioFile file(path.fileSystemRepresentation);
        read = !file.isNull() && file.tag() && file.tag()->title() == "Consumer"
                && [fileTypeForTagLibFile(file.file()) isEqualToString:VibeAudioFileFormatWAV];
    }

    NSData *tagged = [NSData dataWithContentsOfFile:path];
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    if (!read) {
        return Fail("the wrapper did not read the tagged title");
    }
    __block NSUInteger requests = 0;
    VibeTagByteRangeRead rangeRead = ^NSData *(NSURL *url, uint64_t offset, uint64_t length, NSError **error) {
        requests++;
        return offset + length <= tagged.length ? [tagged subdataWithRange:NSMakeRange(offset, length)] : nil;
    };
    NSData *art = nil;
    if (!VibeTagLibReadEmbeddedArt(path, rangeRead, tagged.length, &art) || requests == 0
            || ![art isEqualToData:[NSData dataWithBytes:picture length:sizeof picture - 1]]) {
        return Fail("the wrapper did not read the picture through the range reader");
    }
    return YES;
}
