//
//  VibeFuzzRandom.h
//  vibe-libs
//
//  The fuzz classes' generator and seed, apart from the audio fixtures, so a
//  piece that decodes nothing can fuzz with them.
//

#import <Foundation/Foundation.h>

// xorshift64*, chosen for being four lines rather than for its statistics.
// A state of 0 stays 0, so a seed must be nonzero.
typedef struct { uint64_t state; } VibeFuzzRandom;

static inline uint64_t VibeFuzzNext(VibeFuzzRandom *random) {
    uint64_t x = random->state;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    random->state = x;
    return x * 0x2545F4914F6CDD1DULL;
}

// From the high bits. TRAP: `% bound` kept only the low bits, and seeds that
// differ only in high bits drew the same small numbers first. Every iteration
// of a mutator then made the same mutant.
static inline NSUInteger VibeFuzzBelow(VibeFuzzRandom *random, NSUInteger bound) {
    return (NSUInteger)(((__uint128_t)VibeFuzzNext(random) * bound) >> 64);
}

// VIBE_FUZZ_SEED in decimal or 0x hex, else `fallback`. Fixed by default: a
// suite that explores new inputs on every run passes and fails at random.
static inline uint64_t VibeFuzzBaseSeed(uint64_t fallback) {
    NSString *seed = NSProcessInfo.processInfo.environment[@"VIBE_FUZZ_SEED"];
    return seed ? strtoull(seed.UTF8String, NULL, 0) : fallback;
}
