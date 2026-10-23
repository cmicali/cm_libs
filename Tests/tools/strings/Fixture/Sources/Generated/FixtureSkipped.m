// STRINGS_SKIP leaves this directory out, so this key never reaches the catalog.
#import <Foundation/Foundation.h>

NSString *FixtureSkipped(void) {
    return NSLocalizedString(@"skipped.never", @"A key the sweep must not find.");
}
