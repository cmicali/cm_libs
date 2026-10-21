//
//  main.m
//
//  Plays a ramp through the varispeed at zero pitch and checks it comes back
//  exactly, then renders off zero. Round-trips a color through its hex form.
//  Draws each mac control into a bitmap with no window. Builds a settings
//  window of two panes without showing it, finds a color-pair row, a switch,
//  and a slider in their panes, and picks the second pane in the sidebar.
//  Exits 0 when all five hold.
//

#import <Foundation/Foundation.h>
#import "AudioVarispeed.h"
#import "PlatformColor.h"
#import "CrossfadingImageView.h"
#import "DrawnControls.h"
#import "ScaledImageView.h"
#import "SymbolButton.h"
#import "VibeDetentSlider.h"
#import "VibeLinkLabel.h"
#import "SettingsPanesWindowController.h"
#import "SettingsPaneViewController.h"
#import "SettingsSidebarController.h"

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
    SettingsPanesWindowController *settings = [[SettingsPanesWindowController alloc]
            initWithPaneGroups:@[@[
                [SettingsPanesWindowController paneItemWithViewController:look identifier:@"look"
                                                                    label:@"Look" symbolName:@"paintbrush"],
                [SettingsPanesWindowController paneItemWithViewController:sound identifier:@"sound"
                                                                    label:@"Sound" symbolName:@"speaker.wave.2"],
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
    [settings.window close];
    printf("consumer OK\n");
    return 0;
}
