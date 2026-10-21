//
//  SettingsFormViewsTests.m
//  SettingsWindowTests
//
//  The form views alone, with no window server: titles, enablement, captions,
//  the color-pair row's blocks, and the fill's appearance.
//

#import <XCTest/XCTest.h>
#import "DrawnViewTestSupport.h"
#import "DrawnControls.h"
#import "SettingsFormViews.h"

@interface SettingsFormViewsTests : XCTestCase
@end

@implementation SettingsFormViewsTests

- (void)testRowTitleDropsATrailingColon {
    NSView *control = [[VibeSwitch alloc] init];
    XCTAssertEqualObjects([SettingsRowView rowWithTitle:@"Volume:" control:control].titleLabel.stringValue,
                          @"Volume");
    XCTAssertEqualObjects([SettingsRowView rowWithTitle:@"Volume :" control:control].titleLabel.stringValue,
                          @"Volume");
    XCTAssertEqualObjects([SettingsRowView rowWithTitle:@"音量：" control:control].titleLabel.stringValue,
                          @"音量");
    SettingsRowView *row = [SettingsRowView rowWithTitle:@"Volume" control:control];
    [row setRowTitle:@"Gain:"];
    XCTAssertEqualObjects(row.titleLabel.stringValue, @"Gain");
}

- (void)testSectionHeaderDropsATrailingColon {
    SettingsRowView *row = [SettingsRowView rowWithTitle:@"Volume" control:[[VibeSwitch alloc] init]];
    SettingsSectionView *section = [SettingsSectionView sectionWithHeader:@"Output:" rows:@[row]];
    XCTAssertEqualObjects(section.headerLabel.stringValue, @"Output");
    [section setHeader:@"Input:"];
    XCTAssertEqualObjects(section.headerLabel.stringValue, @"Input");
    XCTAssertEqual([SettingsSectionView sectionContaining:row.titleLabel], section);
    XCTAssertNil([SettingsSectionView sectionContaining:section]);
}

- (void)testAnUntitledRowHasNoTitle {
    SettingsRowView *row = [SettingsRowView rowWithTitle:nil control:[[VibeSwitch alloc] init]];
    XCTAssertNil(row.titleLabel);
    XCTAssertFalse([row setCaption:@"Ignored"]);
}

- (void)testDisablingEveryControlDimsTheRow {
    VibeSwitch *toggle = [[VibeSwitch alloc] init];
    SettingsRowView *row = [SettingsRowView rowWithTitle:@"Volume" caption:@"How loud" control:toggle];
    XCTAssertEqual(row.titleLabel.alphaValue, 1);

    [SettingsRowView setControl:toggle enabled:NO];
    XCTAssertFalse(toggle.enabled);
    XCTAssertEqual(toggle.alphaValue, 0.5);
    XCTAssertEqual(row.titleLabel.alphaValue, 0.5);
    XCTAssertEqual(row.captionLabel.alphaValue, 0.5);

    [SettingsRowView setControlsInView:row enabled:YES];
    XCTAssertTrue(toggle.enabled);
    XCTAssertEqual(toggle.alphaValue, 1);
    XCTAssertEqual(row.titleLabel.alphaValue, 1);
}

- (void)testOneEnabledControlKeepsTheRowLit {
    VibeSwitch *first = [[VibeSwitch alloc] init];
    VibeSwitch *second = [[VibeSwitch alloc] init];
    SettingsRowView *row = [SettingsRowView rowWithTitle:@"Both" controls:@[first, second]];
    [SettingsRowView setControl:first enabled:NO];
    XCTAssertEqual(first.alphaValue, 0.5);
    XCTAssertEqual(row.titleLabel.alphaValue, 1);
}

- (void)testAControlOutsideARowDimsItself {
    VibeSwitch *toggle = [[VibeSwitch alloc] init];
    [SettingsRowView setControl:toggle enabled:NO];
    XCTAssertEqual(toggle.alphaValue, 0.5);
}

- (void)testCaptionAnswersWhenItComesOrGoes {
    SettingsRowView *row = [SettingsRowView rowWithTitle:@"Volume" control:[[VibeSwitch alloc] init]];
    XCTAssertNil(row.captionLabel);
    XCTAssertTrue([row setCaption:@"How loud"]);
    XCTAssertFalse(row.captionLabel.hidden);
    XCTAssertFalse([row setCaption:@"How loud"]);
    XCTAssertTrue([row setCaption:nil]);
    XCTAssertTrue(row.captionLabel.hidden);
    XCTAssertFalse([row setCaption:@""]);
    XCTAssertTrue([row setCaption:@"How loud" detail:@"Muted"]);
    XCTAssertEqualObjects(row.captionLabel.stringValue, @"How loud\nMuted");
}

- (void)testColorRowRefreshesSeedsAndWritesThroughItsBlocks {
    NSMutableArray<NSColor *> *model = [@[NSColor.redColor, NSColor.blueColor] mutableCopy];
    NSMutableArray<NSNumber *> *written = [NSMutableArray array];
    NSMutableArray<NSNumber *> *changes = [NSMutableArray array];
    SettingsColorRow *row = [SettingsColorRow rowWithCaptions:@[@"Dark", @"Light"]
            supportsAlpha:NO
                     read:^NSColor *(NSUInteger index) {
                         return model[index];
                     }
                    write:^(NSUInteger index, NSColor *color) {
                        [written addObject:@(index)];
                        model[index] = color;
                    }
                  changed:^(BOOL continuous) {
                      [changes addObject:@(continuous)];
                  }];
    XCTAssertEqual(row.wells.count, 2u);

    [row refresh];
    XCTAssertTrue(VibeColorsClose(row.wells[0].color, NSColor.redColor, 0.01));
    XCTAssertTrue(VibeColorsClose(row.wells[1].color, NSColor.blueColor, 0.01));
    XCTAssertEqualObjects(written, @[]);

    [row seed];
    XCTAssertEqualObjects(written, (@[@0, @1]));
    XCTAssertEqualObjects(changes, @[]);

    NSColorWell *light = row.wells[1];
    light.color = NSColor.greenColor;
    // NSApp is nil here, so the well's action is sent by hand.
    id target = light.target;
    ((void (*)(id, SEL, id))[target methodForSelector:light.action])(target, light.action, light);
    XCTAssertTrue(VibeColorsClose(model[1], NSColor.greenColor, 0.01));
    XCTAssertEqualObjects(changes, @[@YES]);
}

- (void)testFillFollowsTheAppearance {
    SettingsFillView *fill = [[SettingsFillView alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
    fill.translatesAutoresizingMaskIntoConstraints = YES;
    fill.lightColor = NSColor.whiteColor;
    fill.darkColor = NSColor.blackColor;
    NSWindow *window = VibeOffscreenWindow(NSMakeSize(20, 20));
    [window.contentView addSubview:fill];

    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [fill displayIfNeeded];
    XCTAssertTrue(VibeColorsClose(VibePixel(VibeRenderLayer(fill.layer), NO, 10, 10), NSColor.whiteColor, 0.01));

    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [fill displayIfNeeded];
    XCTAssertTrue(VibeColorsClose(VibePixel(VibeRenderLayer(fill.layer), NO, 10, 10), NSColor.blackColor, 0.01));
}

@end
