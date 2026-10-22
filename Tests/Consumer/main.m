//
//  main.m
//
//  Plays a ramp through the varispeed at zero pitch and checks it comes back
//  exactly, then renders off zero. Round-trips a color through its hex form.
//  Draws each mac control into a bitmap with no window. Builds a settings
//  window of three panes without showing it, finds a color-pair row, a switch,
//  and a slider in two of them, and picks the second pane in the sidebar. In
//  the third, the Shortcuts pane over two commands of its own, it records a
//  shortcut from a key event sent through NSApp. Keys a temporary file by its
//  size, time and path, and keys it anew once it changes. Turns a CUE window
//  into a file's frames. Opens a temporary file through the file loader, with
//  a handle of its own. Roots a disk cache in a temporary directory and reads
//  its usage back. Finds the tempo of a click track at 128 BPM, fed in
//  blocks as a decode would. Exits 0 when all eleven hold.
//

#import <Foundation/Foundation.h>
#import <math.h>
#import "AudioBPMAnalyzer.h"
#import "AudioFileMaterializationCoordinator.h"
#import "AudioVarispeed.h"
#import "CueWindowMath.h"
#import "PINCache+VibeAudioCache.h"
#import "NSURL+Hash.h"
#import "PlatformColor.h"
#import "CrossfadingImageView.h"
#import "DrawnControls.h"
#import "ScaledImageView.h"
#import "SymbolButton.h"
#import "VibeDetentSlider.h"
#import "VibeLinkLabel.h"
#import "SettingsPanesWindowController.h"
#import "SettingsPaneViewController.h"
#import "SettingsShortcutsViewController.h"
#import "SettingsSidebarController.h"
#import "ShortcutLayout.h"

// A pane whose sections a block builds, so main needs no pane classes.
@interface ConsumerPane : SettingsPaneViewController
@property (nonatomic, copy) NSArray<NSView *> *(^build)(ConsumerPane *pane);
@end

@implementation ConsumerPane
- (void)loadView {
    [self loadPaneWithSections:self.build(self)];
}
- (void)changed:(id)sender {
}
@end

// The handle the file loader serves. It reads no stream, so it ignores the
// hold.
@interface ConsumerFile : NSObject <ServedFileHandle>
@property (nonatomic, strong) NSURL *url;
@end

@implementation ConsumerFile
- (void)holdStream {
}
@end

// Runs main's loop until done says so, for at most ten seconds.
// Thirty seconds of the analyzer tests' click track: a short decaying burst
// on each beat over a quiet tone. Fed in 4096-frame blocks.
static float ClickTrackTempo(double bpm) {
    const double rate = 44100.0;
    const size_t total = (size_t)(rate * 30.0);
    const double period = 60.0 / bpm * rate;
    float *audio = malloc(total * sizeof(float));
    for (size_t i = 0; i < total; i++) {
        double sinceBeat = fmod((double)i, period);
        double click = exp(-sinceBeat / 200.0) * sin((double)i * 0.7);
        audio[i] = (float)(0.9 * click + 0.05 * sin((double)i * 0.03));
    }
    AudioBPMAnalyzer *analyzer = [[AudioBPMAnalyzer alloc] initWithSampleRate:rate];
    for (size_t offset = 0; offset < total; offset += 4096) {
        [analyzer appendMonoSamples:audio + offset frameCount:MIN((size_t)4096, total - offset)];
    }
    free(audio);
    return [analyzer finish];
}

static BOOL Settles(BOOL (^done)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done() && deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return done();
}

// The first view of a class under a view that passes a test, the view included.
static __kindof NSView *Find(NSView *view, Class kind, BOOL (^match)(id view)) {
    if ([view isKindOfClass:kind] && match(view)) {
        return view;
    }
    for (NSView *child in view.subviews) {
        NSView *found = Find(child, kind, match);
        if (found) {
            return found;
        }
    }
    return nil;
}

// How many views of a class sit under a view, the view included.
static NSUInteger Count(NSView *view, Class kind) {
    NSUInteger count = [view isKindOfClass:kind] ? 1 : 0;
    for (NSView *child in view.subviews) {
        count += Count(child, kind);
    }
    return count;
}

// Whether a view, drawn into a bitmap with no window, shows any pixel.
static BOOL Draws(NSView *view) {
    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
    for (NSInteger y = 0; y < rep.pixelsHigh; y++) {
        for (NSInteger x = 0; x < rep.pixelsWide; x++) {
            if ([rep colorAtX:x y:y].alphaComponent > 0) {
                return YES;
            }
        }
    }
    return NO;
}

enum { kFrames = 512 };

static OSStatus Ramp(void *context, const AudioTimeStamp *stamp, UInt32 frames, AudioBufferList *into) CA_REALTIME_API {
    uint64_t *next = context;
    for (UInt32 c = 0; c < into->mNumberBuffers; c++) {
        float *out = into->mBuffers[c].mData;
        for (UInt32 n = 0; n < frames; n++) {
            out[n] = (float)((*next + n) % 1024) / 1024.0f;
        }
    }
    *next += frames;
    return noErr;
}

int main(void) {
    VibeVarispeed *stage = VibeVarispeedCreate(2, kFrames);
    if (!stage) {
        fprintf(stderr, "consumer: no stage\n");
        return 1;
    }
    float left[kFrames], right[kFrames];
    VibeStereoBufferList out = { 2, {{1, sizeof left, left}, {1, sizeof right, right}} };
    AudioTimeStamp stamp = {0};
    uint64_t next = 0;
    for (int slice = 0; slice < 8; slice++) {
        uint64_t first = next;
        VibeVarispeedRender(stage, Ramp, &next, &stamp, kFrames, (AudioBufferList *)&out);
        for (UInt32 n = 0; n < kFrames; n++) {
            float want = (float)((first + n) % 1024) / 1024.0f;
            if (left[n] != want || right[n] != want) {
                fprintf(stderr, "consumer: frame %llu is %f, not %f\n", first + n, left[n], want);
                return 1;
            }
        }
    }
    VibeVarispeedTable *replaced = NULL;
    if (!VibeVarispeedSetPitch(stage, 2.0, &replaced)) {
        fprintf(stderr, "consumer: no table\n");
        return 1;
    }
    for (int slice = 0; slice < 8; slice++) {
        VibeVarispeedRender(stage, Ramp, &next, &stamp, kFrames, (AudioBufferList *)&out);
    }
    if (replaced) {
        VibeVarispeedRetire(stage, replaced);
    }
    BOOL engaged = VibeVarispeedEngaged(stage);
    VibeVarispeedFree(stage);
    if (!engaged) {
        fprintf(stderr, "consumer: the converter never joined\n");
        return 1;
    }
    NSString *hex = VibeHexStringFromColor(VibeColorFromHexString(@"#12345678"));
    if (![hex isEqualToString:@"#12345678"]) {
        fprintf(stderr, "consumer: the color came back as %s\n", hex.UTF8String);
        return 1;
    }
    NSRect frame = NSMakeRect(0, 0, 120, 20);
    VibeSlider *slider = [[VibeSlider alloc] initWithFrame:frame];
    slider.doubleValue = 0.5;
    VibeSwitch *toggle = [[VibeSwitch alloc] initWithFrame:NSMakeRect(0, 0, 44, 20)];
    VibeDetentSlider *detent = [[VibeDetentSlider alloc] initWithFrame:frame];
    detent.detentValue = 0.5;
    SymbolButton *button = [[SymbolButton alloc] initWithFrame:NSMakeRect(0, 0, 30, 30)];
    button.symbolName = @"play.fill";
    NSImage *note = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
    ScaledImageView *scaled = [[ScaledImageView alloc] initWithFrame:frame];
    scaled.image = note;
    CrossfadingImageView *crossfading = [[CrossfadingImageView alloc] initWithFrame:frame];
    crossfading.image = note;
    VibeLinkLabel *link = [VibeLinkLabel labelWithString:@"vibe-libs"];
    link.linkURL = [NSURL URLWithString:@"https://github.com/cmicali/vibe-libs"];
    link.linkRange = NSMakeRange(0, 9);
    for (NSView *view in @[slider, toggle, detent, button, scaled, crossfading, link]) {
        if (!Draws(view)) {
            fprintf(stderr, "consumer: %s drew nothing\n", view.className.UTF8String);
            return 1;
        }
    }
    NSMutableArray<NSColor *> *pair = [@[NSColor.blackColor, NSColor.whiteColor] mutableCopy];
    ConsumerPane *look = [[ConsumerPane alloc] initWithEffectsSink:^(NSUInteger effects) {}];
    look.build = ^NSArray<NSView *> *(ConsumerPane *pane) {
        SettingsColorRow *colors = [SettingsColorRow rowWithCaptions:@[@"Dark", @"Light"]
                supportsAlpha:NO
                         read:^NSColor *(NSUInteger index) { return pair[index]; }
                        write:^(NSUInteger index, NSColor *color) { pair[index] = color; }
                      changed:^(BOOL continuous) {}];
        return @[[SettingsSectionView sectionWithHeader:@"Look" rows:@[
            [SettingsRowView rowWithTitle:@"Accent" control:colors],
            [SettingsRowView rowWithTitle:@"Compact" control:[pane switchWithAction:@selector(changed:)]],
        ]]];
    };
    ConsumerPane *sound = [[ConsumerPane alloc] initWithEffectsSink:^(NSUInteger effects) {}];
    sound.build = ^NSArray<NSView *> *(ConsumerPane *pane) {
        NSSlider *volume = nil;
        NSTextField *readout = nil;
        NSStackView *cluster = [pane detentSliderClusterWithDetent:0.5 min:0 max:1 action:@selector(changed:) width:160
                                                            slider:&volume valueLabel:&readout];
        return @[[SettingsSectionView sectionWithRows:@[[SettingsRowView rowWithTitle:@"Volume" control:cluster]]]];
    };
    // The recorder's monitor sees only events NSApp sends.
    [NSApplication sharedApplication];
    VibeShortcutSetKeyNames(@"Space", @"Keypad %@", @"Key %ld", @"None");
    NSArray<NSArray *> *commands = @[@[@"zoom_in", @(kVibeShortcutNone)], @[@"zoom_out", @(kVibeShortcutNone)]];
    NSMutableDictionary<NSString *, NSNumber *> *bindings = [NSMutableDictionary dictionary];
    NSMutableArray<NSNumber *> *assigned = [NSMutableArray array];
    SettingsShortcutsViewController *keys = [[SettingsShortcutsViewController alloc]
            initWithEffectsSink:^(NSUInteger effects) {}
                    commandRows:^{ return @[@[@"View", @[@[@"zoom_in", @"Zoom In"], @[@"zoom_out", @"Zoom Out"]]]]; }
             shortcutForCommand:^(NSString *identifier) { return VibeShortcutEffective(commands, identifier, bindings); }
                      overrides:^{ return [bindings copy]; }
                   setOverrides:^(NSDictionary<NSString *, NSNumber *> *overrides) { [bindings setDictionary:overrides]; }
                         assign:^(VibeShortcut shortcut, NSString *identifier, NSString **loser) {
                             [assigned addObject:@(shortcut)];
                             [bindings setDictionary:VibeShortcutOverridesByAssigning(commands, bindings, identifier,
                                                                                      shortcut, 0, loser)];
                             return VibeShortcutAssignmentStored;
                         }];
    keys.commandColumnTitle = @"Command";
    keys.shortcutColumnTitle = @"Shortcut";
    keys.recordTitle = @"Record Shortcut";
    keys.clearTitle = @"Clear";
    keys.resetAllTitle = @"Reset All";
    keys.explainer = @"Select a command, then record its shortcut.";
    keys.layoutNote = @"Keys follow the keyboard layout.";
    keys.selectTip = @"Select a command first.";
    keys.noneTip = @"This command has no shortcut.";
    keys.defaultsTip = @"Every shortcut is its default.";
    keys.undoActionName = @"Change Shortcut";
    keys.recordingFormat = @"Type a shortcut for %@.";
    keys.reservedFormat = @"%@ is reserved.";
    keys.unusableCaption = @"That key cannot be shown.";
    keys.reassignedFormat = @"%@ moved to %@ from %@.";
    SettingsPanesWindowController *settings = [[SettingsPanesWindowController alloc]
            initWithPaneGroups:@[@[
                [SettingsPanesWindowController paneItemWithViewController:look identifier:@"look"
                                                                    label:@"Look" symbolName:@"paintbrush"],
                [SettingsPanesWindowController paneItemWithViewController:sound identifier:@"sound"
                                                                    label:@"Sound" symbolName:@"speaker.wave.2"],
                [SettingsPanesWindowController paneItemWithViewController:keys identifier:@"keys"
                                                                    label:@"Keys" symbolName:@"keyboard"],
            ]]
                     backTitle:@"Back" forwardTitle:@"Forward" undoTitle:@"Undo" redoTitle:@"Redo"
             searchPlaceholder:@"Search" noResultsText:@"No Results"];
    if (Count(look.view, SettingsColorRow.class) != 1 || Count(look.view, VibeSwitch.class) != 1
            || Count(look.view, NSSlider.class) != 0 || Count(sound.view, NSSlider.class) != 1) {
        fprintf(stderr, "consumer: the panes do not hold the color pair, the switch, and the slider\n");
        return 1;
    }
    NSSplitViewController *split = (NSSplitViewController *)settings.window.contentViewController;
    SettingsSidebarController *sidebar =
            (SettingsSidebarController *)split.splitViewItems.firstObject.viewController;
    [sidebar.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
    if (![settings.selectedTabItem.identifier isEqual:@"sound"] || ![settings.window.title isEqual:@"Sound"]
            || settings.window.isVisible) {
        fprintf(stderr, "consumer: the sidebar did not select the second pane\n");
        return 1;
    }
    [sidebar.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
    [keys refreshFromSettings];
    NSTableView *list = Find(keys.view, NSTableView.class, ^BOOL(id view) { return YES; });
    [list selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
    NSButton *record = Find(keys.view, NSButton.class, ^BOOL(NSButton *button) {
        return [button.title isEqualToString:@"Record Shortcut"];
    });
    [record performClick:nil];
    NSEventModifierFlags held = NSEventModifierFlagControl | NSEventModifierFlagOption;
    for (NSNumber *type in @[@(NSEventTypeKeyDown), @(NSEventTypeKeyUp)]) {
        [NSApp sendEvent:[NSEvent keyEventWithType:(NSEventType)type.unsignedIntegerValue location:NSZeroPoint
                                     modifierFlags:held timestamp:0 windowNumber:settings.window.windowNumber
                                           context:nil characters:@"" charactersIgnoringModifiers:@""
                                         isARepeat:NO keyCode:0]];
    }
    VibeShortcut recorded = VibeShortcutMake(0, held);
    NSTableCellView *cell = [list viewAtColumn:1 row:1 makeIfNecessary:YES];
    if (![assigned isEqual:@[@(recorded)]] || ![bindings isEqual:@{@"zoom_in": @(recorded)}]
            || ![cell.textField.stringValue isEqualToString:VibeShortcutDisplayString(recorded)]) {
        fprintf(stderr, "consumer: the pane did not record ⌃⌥ and the key, and shows %s\n",
                cell.textField.stringValue.UTF8String);
        return 1;
    }
    [settings.window close];
    NSURL *file = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    [[NSData dataWithBytes:"one" length:3] writeToURL:file atomically:YES];
    NSString *key = file.cacheKey;
    [[NSData dataWithBytes:"four" length:4] writeToURL:file atomically:YES];
    NSString *changed = file.cacheKey;
    [NSFileManager.defaultManager removeItemAtURL:file error:NULL];
    if (![key hasPrefix:@"3-"] || ![changed hasPrefix:@"4-"] || file.cacheKey) {
        fprintf(stderr, "consumer: the disk keys were %s, then %s\n", key.UTF8String, changed.UTF8String);
        return 1;
    }
    NSRange window = VibeCueWindow(75, 150, 48000, 480000, NO);
    if (!NSEqualRanges(window, NSMakeRange(48000, 48000))) {
        fprintf(stderr, "consumer: the window is %s\n", NSStringFromRange(window).UTF8String);
        return 1;
    }
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
                                            attributes:nil error:NULL];
    NSURL *track = [directory URLByAppendingPathComponent:@"track.bin"];
    [[NSData dataWithBytes:"bytes" length:5] writeToURL:track atomically:YES];
    __block ConsumerFile *served = nil;
    __block NSError *openError = nil;
    __block BOOL opened = NO;
    [AudioFileMaterializationCoordinator.sharedCoordinator openURL:track
            purpose:VibeAudioFileOpenPurposePlayback
             opener:^id<ServedFileHandle>(NSURL *url, BOOL (^interrupted)(void), NSError **error) {
        ConsumerFile *file = [[ConsumerFile alloc] init];
        file.url = url;
        return file;
    } completionQueue:dispatch_get_main_queue() onDataless:nil
         completion:^(id<ServedFileHandle> file, NSError *error, NSTimeInterval elapsed) {
        served = (ConsumerFile *)file;
        openError = error;
        opened = YES;
    }];
    if (!Settles(^BOOL { return opened; }) || ![served.url isEqual:track]) {
        fprintf(stderr, "consumer: the loader served %s (%s)\n", served.url.path.UTF8String,
                openError.localizedDescription.UTF8String);
        return 1;
    }
    PINCache *cache = [PINCache audioCacheWithName:@"consumer" rootPath:directory.path];
    [cache.diskCache setObject:@"entry" forKey:@"key"];
    __block NSUInteger entries = 0;
    __block BOOL counted = NO;
    [cache audioDiskUsageWithCompletion:^(NSUInteger fileCount, unsigned long long totalBytes) {
        entries = fileCount;
        counted = YES;
    }];
    BOOL cached = Settles(^BOOL { return counted; }) && entries == 1
            && [cache.diskCache.cacheURL.path hasPrefix:directory.path]
            && [(NSString *)[cache.diskCache objectForKey:@"key"] isEqual:@"entry"];
    [NSFileManager.defaultManager removeItemAtURL:directory error:NULL];
    if (!cached) {
        fprintf(stderr, "consumer: the disk cache holds %lu entries\n", (unsigned long)entries);
        return 1;
    }
    float tempo = ClickTrackTempo(128.0);
    if (fabsf(tempo - 128.0f) > 1.0f) {
        fprintf(stderr, "consumer: the click track's tempo is %.2f\n", tempo);
        return 1;
    }
    printf("consumer OK\n");
    return 0;
}
