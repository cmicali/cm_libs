//
//  DrawnControlsTests.m
//  vibe-libs
//
//  VibeSlider and VibeSwitch drawn into a bitmap, with no window server. A
//  deferred window is never key, so the fills drawn here are the not-key ones.
//  NSApp is nil host-less, so sent actions go nowhere and are not asserted.
//

#import <XCTest/XCTest.h>

#import "DrawnViewTestSupport.h"
#import "DrawnControls.h"

static const CGFloat kSliderWidth = 120;
static const CGFloat kSliderHeight = 20;
// The knob's center travels from half a knob in from each end.
static const CGFloat kKnobHalf = 9;

@interface DrawnControlsTests : XCTestCase
@end

@implementation DrawnControlsTests {
    NSWindow *_window;
}

- (void)setUp {
    [super setUp];
    _window = VibeOffscreenWindow(NSMakeSize(200, 100));
}

- (VibeSlider *)sliderAt:(double)value dark:(BOOL)dark {
    VibeSlider *slider = [[VibeSlider alloc] initWithFrame:NSMakeRect(0, 0, kSliderWidth, kSliderHeight)];
    slider.appearance = [NSAppearance appearanceNamed:dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    slider.doubleValue = value;
    return slider;
}

- (CGFloat)knobXForValue:(double)value {
    return kKnobHalf + value * (kSliderWidth - 2 * kKnobHalf);
}

- (void)send:(NSEventType)type x:(CGFloat)x to:(NSControl *)control {
    NSEvent *event = [NSEvent mouseEventWithType:type location:NSMakePoint(x, kSliderHeight / 2)
                                   modifierFlags:0 timestamp:0 windowNumber:_window.windowNumber
                                         context:nil eventNumber:0 clickCount:1 pressure:1];
    switch (type) {
        case NSEventTypeLeftMouseDown: [control mouseDown:event]; break;
        case NSEventTypeLeftMouseDragged: [control mouseDragged:event]; break;
        default: [control mouseUp:event]; break;
    }
}

#pragma mark - VibeSlider

- (void)testTheSliderFillsUpToItsValue {
    for (NSNumber *value in @[@0.25, @0.5, @0.75]) {
        NSBitmapImageRep *rep = VibeRenderView([self sliderAt:value.doubleValue dark:YES]);
        CGFloat knob = [self knobXForValue:value.doubleValue];
        NSColor *filled = VibePixel(rep, NO, knob - kKnobHalf - 3, kSliderHeight / 2);
        NSColor *unfilled = VibePixel(rep, NO, knob + kKnobHalf + 3, kSliderHeight / 2);
        XCTAssertGreaterThan(filled.alphaComponent, unfilled.alphaComponent + 0.05, @"%@", value);
        XCTAssertGreaterThan(unfilled.alphaComponent, 0, @"the track shows past the knob");
        NSColor *knobPixel = VibePixel(rep, NO, knob, kSliderHeight / 2);
        XCTAssertGreaterThan(knobPixel.alphaComponent, 0.95, @"the knob is opaque at %@", value);
    }
}

- (void)testDisabledDrawsAtHalfAlpha {
    VibeSlider *slider = [self sliderAt:0.5 dark:YES];
    CGFloat knob = [self knobXForValue:0.5];
    CGFloat enabled = VibePixel(VibeRenderView(slider), NO, knob, kSliderHeight / 2).alphaComponent;
    slider.enabled = NO;
    CGFloat disabled = VibePixel(VibeRenderView(slider), NO, knob, kSliderHeight / 2).alphaComponent;
    XCTAssertEqualWithAccuracy(disabled, enabled * 0.5, 0.03);
}

- (void)testTheTrackFollowsTheAppearance {
    CGFloat x = kSliderWidth - 3;
    NSColor *dark = VibePixel(VibeRenderView([self sliderAt:0 dark:YES]), NO, x, kSliderHeight / 2);
    NSColor *light = VibePixel(VibeRenderView([self sliderAt:0 dark:NO]), NO, x, kSliderHeight / 2);
    // Premultiplied: white at 0.1 reads brighter than black at 0.1.
    XCTAssertGreaterThan(dark.redComponent, light.redComponent);
}

- (void)testAKnobColorReplacesTheSystemKnob {
    VibeSlider *slider = [self sliderAt:0.5 dark:NO];
    slider.knobColor = NSColor.redColor;
    NSColor *knob = VibePixel(VibeRenderView(slider), NO, [self knobXForValue:0.5], kSliderHeight / 2);
    XCTAssertGreaterThan(knob.redComponent, 0.9);
    XCTAssertLessThan(knob.greenComponent, 0.1);
}

- (void)testAClickJumpsAndADragClamps {
    VibeSlider *slider = [self sliderAt:0 dark:YES];
    [_window.contentView addSubview:slider];
    [self send:NSEventTypeLeftMouseDown x:[self knobXForValue:0.5] to:slider];
    XCTAssertEqualWithAccuracy(slider.doubleValue, 0.5, 1e-9);
    [self send:NSEventTypeLeftMouseDragged x:kSliderWidth + 50 to:slider];
    XCTAssertEqual(slider.doubleValue, 1);
    [self send:NSEventTypeLeftMouseUp x:kSliderWidth + 50 to:slider];

    slider.enabled = NO;
    [self send:NSEventTypeLeftMouseDown x:[self knobXForValue:0.2] to:slider];
    XCTAssertEqual(slider.doubleValue, 1, @"a disabled slider ignores the press");
}

- (void)testTheValueClampsAndAccessibilityStepsToFivePercentMarks {
    VibeSlider *slider = [self sliderAt:1.5 dark:YES];
    XCTAssertEqual(slider.doubleValue, 1);
    slider.doubleValue = NAN;
    XCTAssertEqual(slider.doubleValue, 0);
    slider.doubleValue = 0.52;
    XCTAssertTrue([slider accessibilityPerformIncrement]);
    XCTAssertEqualWithAccuracy(slider.doubleValue, 0.55, 1e-9);
    slider.doubleValue = 1;
    XCTAssertFalse([slider accessibilityPerformIncrement]);
    slider.enabled = NO;
    XCTAssertFalse([slider accessibilityPerformDecrement]);
}

// The spoken value is whatever the shell installs; the control formats nothing.
- (void)testTheSpokenValueComesFromTheInstalledFormatter {
    VibeSlider *slider = [self sliderAt:0.5 dark:YES];
    XCTAssertNil(slider.accessibilityValueDescription);
    slider.accessibilityValueFormatter = ^NSString *(double value) {
        return [NSString stringWithFormat:@"%.0f of 100", value * 100];
    };
    XCTAssertEqualObjects(slider.accessibilityValueDescription, @"50 of 100");
    slider.doubleValue = 0.25;
    XCTAssertEqualObjects(slider.accessibilityValueDescription, @"25 of 100");
}

// The scroll and arrow keys' move: 5% a step, unrounded, clamped, and NO
// when it did not move.
- (void)testAMoveIsExactAndClamps {
    VibeSlider *slider = [self sliderAt:0.52 dark:YES];
    XCTAssertTrue([slider moveBySteps:0.3]);
    XCTAssertEqualWithAccuracy(slider.doubleValue, 0.535, 1e-9);
    XCTAssertTrue([slider moveBySteps:20]);
    XCTAssertEqual(slider.doubleValue, 1);
    XCTAssertFalse([slider moveBySteps:1]);
    slider.enabled = NO;
    XCTAssertFalse([slider moveBySteps:-1]);
    XCTAssertEqual(slider.doubleValue, 1);
}

#pragma mark - VibeSwitch

- (VibeSwitch *)switchOn:(BOOL)on {
    VibeSwitch *control = [[VibeSwitch alloc] initWithFrame:NSMakeRect(0, 0, 44, 20)];
    control.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    control.state = on ? NSControlStateValueOn : NSControlStateValueOff;
    return control;
}

- (void)testTheSwitchKnobSitsOnItsStateSide {
    // The knob is opaque white on light. The off track is black at 0.1.
    NSBitmapImageRep *off = VibeRenderView([self switchOn:NO]);
    NSBitmapImageRep *on = VibeRenderView([self switchOn:YES]);
    XCTAssertGreaterThan(VibePixel(off, NO, 13, 10).alphaComponent, 0.95);
    XCTAssertLessThan(VibePixel(off, NO, 35, 10).alphaComponent, 0.5);
    XCTAssertGreaterThan(VibePixel(on, NO, 31, 10).alphaComponent, 0.95);
    XCTAssertFalse([off.TIFFRepresentation isEqual:on.TIFFRepresentation]);
}

- (void)testADisabledSwitchDimsAndRefusesToToggle {
    VibeSwitch *control = [self switchOn:NO];
    CGFloat enabled = VibePixel(VibeRenderView(control), NO, 13, 10).alphaComponent;
    control.enabled = NO;
    CGFloat disabled = VibePixel(VibeRenderView(control), NO, 13, 10).alphaComponent;
    XCTAssertEqualWithAccuracy(disabled, enabled * 0.5, 0.03);
    XCTAssertFalse([control accessibilityPerformPress]);
    XCTAssertEqual(control.state, NSControlStateValueOff);
}

- (void)testPressAndSpaceToggleButSettingStateIsSilent {
    VibeSwitch *control = [self switchOn:NO];
    XCTAssertEqualObjects(control.accessibilityValue, @NO);
    XCTAssertTrue([control accessibilityPerformPress]);
    XCTAssertEqual(control.state, NSControlStateValueOn);
    NSEvent *space = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0
                                     timestamp:0 windowNumber:0 context:nil characters:@" "
                   charactersIgnoringModifiers:@" " isARepeat:NO keyCode:49];
    [control keyDown:space];
    XCTAssertEqual(control.state, NSControlStateValueOff);
    control.state = 7;
    XCTAssertEqual(control.state, NSControlStateValueOn, @"any non-off state is on");
}

@end
