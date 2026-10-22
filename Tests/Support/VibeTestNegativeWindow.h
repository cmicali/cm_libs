// A negative check's window: an inverted expectation, or a fixed wait before
// asserting nothing arrived. Short, since every pass runs its full length.
// Vibe's tests use the same window.

#import <Foundation/Foundation.h>

static const NSTimeInterval kVibeTestNegativeWindow = 0.2;
