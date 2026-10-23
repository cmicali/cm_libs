// The self-test's registry, in the shape extract-strings.sh reads.

#ifndef FixtureStrings_h
#define FixtureStrings_h

#ifndef VIBE_STRINGS_EXTRACTION
#import <Foundation/Foundation.h>
#endif

#define NSLS(key, value, comment) NSLocalizedStringWithDefaultValue(key, nil, NSBundle.mainBundle, value, comment)

#define STR_GREETING NSLS(@"greeting.hello", @"Hello, %@", @"A greeting. %@ is the listener's name.")
#define STR_FAREWELL NSLS(@"greeting.bye", @"Goodbye", @"A farewell.")
#define STR_EXTENSION_TITLE NSLS(@"extension.title", @"Now Playing", @"The extension's title.")

#endif
