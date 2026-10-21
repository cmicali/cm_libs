//
//  SettingsFormViewsDebugTests.m
//  SettingsWindowTests
//
//  The walker's seam: each control in a card, named by the row it sits in.
//

#import <XCTest/XCTest.h>
#import "DrawnControls.h"
#import "VibeDetentSlider.h"
#import "SettingsFormViews+Debug.h"

@interface SettingsFormViewsDebugTests : XCTestCase
@end

@implementation SettingsFormViewsDebugTests

- (void)testEachControlAnswersToItsRow {
    VibeSwitch *toggle = [[VibeSwitch alloc] init];
    VibeDetentSlider *slider = [VibeDetentSlider sliderWithValue:0.5 minValue:0 maxValue:1
                                                          target:nil action:nil];
    NSTextField *readout = [NSTextField labelWithString:@"50%"];
    NSButton *checkbox = [NSButton checkboxWithTitle:@"Loud" target:nil action:nil];
    NSButton *push = [NSButton buttonWithTitle:@"Reset" target:nil action:nil];
    NSColorWell *well = [[NSColorWell alloc] init];
    SettingsRowView *switchRow = [SettingsRowView rowWithTitle:@"Dark mode:" control:toggle];
    SettingsRowView *sliderRow = [SettingsRowView rowWithTitle:@"Volume" caption:@"How loud"
                                                      controls:@[slider, readout]];
    SettingsRowView *buttonRow = [SettingsRowView rowWithTitle:nil controls:@[checkbox, push]];
    SettingsRowView *wellRow = [SettingsRowView rowWithTitle:@"Accent" control:well];
    SettingsSectionView *section = [SettingsSectionView sectionWithHeader:@"Output"
            rows:@[switchRow, sliderRow, buttonRow, wellRow]];

    NSArray<VibeSettingsElement *> *elements = [SettingsRowView debugElementsInView:section];

    NSMutableArray<NSString *> *kinds = [NSMutableArray array];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (VibeSettingsElement *element in elements) {
        [kinds addObject:element.kind];
        [names addObject:element.name];
    }
    XCTAssertEqualObjects(kinds, (@[@"switch", @"slider", @"label", @"checkbox", @"button", @"colorwell"]));
    // A button names itself. Every other control takes its row's title, and
    // an untitled row takes its section's header.
    XCTAssertEqualObjects(names, (@[@"Dark mode", @"Volume", @"Volume", @"Loud", @"Reset", @"Accent"]));
    XCTAssertEqual(elements[0].view, toggle);
    XCTAssertEqual(elements[0].row, switchRow);
    XCTAssertEqual(elements[1].row, sliderRow);
    XCTAssertEqualObjects(elements[3].label, @"Output");
    XCTAssertEqual(elements[3].row, buttonRow);
}

- (void)testAViewOutsideEveryRowHasNoLabel {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    NSTextField *field = [NSTextField textFieldWithString:@"typed"];
    [container addSubview:field];
    NSArray<VibeSettingsElement *> *elements = [SettingsRowView debugElementsInView:container];
    XCTAssertEqual(elements.count, 1u);
    XCTAssertEqualObjects(elements[0].kind, @"field");
    XCTAssertEqualObjects(elements[0].name, @"typed");
    XCTAssertNil(elements[0].label);
    XCTAssertNil(elements[0].row);
}

@end
