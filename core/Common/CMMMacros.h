//
//  CMMMacros.h
//
//  Macros a file imports explicitly, so it builds without an app's prefix
//  header.
//

#pragma once

// VIBE_REALTIME_CHECKED_BEGIN … VIBE_REALTIME_END compiles its body under
// -Werror=function-effects, so a CA_REALTIME_API function there cannot
// allocate, lock, log, dispatch or message. VIBE_REALTIME_UNCHECKED_BEGIN
// brackets only the one-line shims around calls the checker cannot see
// (AudioUnitRender, the vDSP FFT, the clock), each documented at its site.
#if defined(__has_warning) && __has_warning("-Wfunction-effects")
#define VIBE_REALTIME_CHECKED_BEGIN   _Pragma("clang diagnostic push") _Pragma("clang diagnostic error \"-Wfunction-effects\"")
#define VIBE_REALTIME_UNCHECKED_BEGIN _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wfunction-effects\"")
#define VIBE_REALTIME_END             _Pragma("clang diagnostic pop")
#else
#define VIBE_REALTIME_CHECKED_BEGIN
#define VIBE_REALTIME_UNCHECKED_BEGIN
#define VIBE_REALTIME_END
#endif

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <os/log.h>

NS_ASSUME_NONNULL_BEGIN

// The log every piece writes to, under the app's own bundle identifier, so
// each app's messages stream under its own name.
static inline os_log_t VibeLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *subsystem = NSBundle.mainBundle.bundleIdentifier ?: @"cm_libs";
        log = os_log_create(subsystem.UTF8String, "app");
    });
    return log;
}

// Skips the formatting for a level os_log discards.
// TRAP: nothing else goes in this test or in the emit below. Every log site in
// every piece inlines them. With a stderr hook added here, the metadata-scan
// benchmarks, which never log, retired 2 to 3% more instructions. To copy
// messages to stderr, an app sets OS_ACTIVITY_DT_MODE.
static inline BOOL VibeLogWants(os_log_type_t type) {
    return os_log_type_enabled(VibeLog(), type);
}

// os_log needs a constant format, so messages arrive pre-formatted; %{public}
// stops os_log redacting them.
static inline void VibeLogEmit(os_log_type_t type, NSString *message) {
    os_log_with_type(VibeLog(), type, "%{public}@", message);
}

#define VibeLogAt(type, fmt, ...)                                                              \
    do {                                                                                       \
        if (VibeLogWants(type)) {                                                              \
            VibeLogEmit(type, [NSString stringWithFormat:(fmt), ##__VA_ARGS__]);               \
        }                                                                                      \
    } while (0)

#define LogError(fmt, ...)  VibeLogAt(OS_LOG_TYPE_ERROR, fmt, ##__VA_ARGS__)
#define LogWarn(fmt, ...)   VibeLogAt(OS_LOG_TYPE_DEFAULT, fmt, ##__VA_ARGS__)

// VIBE_VERBOSE_LOGGING, a build setting of the app's, writes info and debug
// at Default level, so they are kept for a later export. Errors keep Error
// level. Warn always uses Default.
#if VIBE_VERBOSE_LOGGING
#define LogInfo(fmt, ...)   VibeLogAt(OS_LOG_TYPE_DEFAULT, fmt, ##__VA_ARGS__)
#define LogDebug(fmt, ...)  VibeLogAt(OS_LOG_TYPE_DEFAULT, fmt, ##__VA_ARGS__)
#else
#define LogInfo(fmt, ...)   VibeLogAt(OS_LOG_TYPE_INFO, fmt, ##__VA_ARGS__)
#define LogDebug(fmt, ...)  VibeLogAt(OS_LOG_TYPE_DEBUG, fmt, ##__VA_ARGS__)
#endif

// Log timed steps at Warn level. Without verbose logging, only those over
// their threshold.
#if VIBE_VERBOSE_LOGGING
#define LogTiming(slow, fmt, ...)  LogWarn(fmt, ##__VA_ARGS__)
#else
#define LogTiming(slow, fmt, ...)                                                              \
    do {                                                                                       \
        if (slow) {                                                                            \
            LogWarn(fmt, ##__VA_ARGS__);                                                       \
        }                                                                                      \
    } while (0)
#endif

NS_ASSUME_NONNULL_END

#endif // __OBJC__
