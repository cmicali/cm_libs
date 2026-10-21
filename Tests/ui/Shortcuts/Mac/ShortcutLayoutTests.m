//
//  ShortcutLayoutTests.m
//  ShortcutsTests
//
//  A shortcut under the runner's own layout. Each test asks the layout what
//  a key types rather than naming a letter, so any ASCII-capable layout
//  passes.
//

#import <XCTest/XCTest.h>
#import "ShortcutLayout.h"

@interface ShortcutLayoutTests : XCTestCase
@end

@implementation ShortcutLayoutTests

static const NSEventModifierFlags kCmd = NSEventModifierFlagCommand;

- (void)setUp {
    VibeShortcutSetKeyNames(@"Space", @"Keypad %@", @"Key %ld", @"None");
}

- (void)testALetterKeyTypesALetterAndThatLetterNamesTheKey {
    // kVK_ANSI_A, a letter on every ASCII-capable layout.
    unichar character = VibeShortcutCharacterForKeyCode(0, 0);
    XCTAssertTrue([NSCharacterSet.lowercaseLetterCharacterSet characterIsMember:character]);
    XCTAssertEqual(VibeShortcutKeyCodeForCharacter(character, 0), 0);
    NSString *letter = [NSString stringWithCharacters:&character length:1];
    XCTAssertEqualObjects(VibeShortcutKeyLabel(0, 0), letter.uppercaseString);
    XCTAssertEqualObjects(VibeShortcutDisplayString(VibeShortcutMake(0, NSEventModifierFlagControl
                                                                         | NSEventModifierFlagOption | kCmd)),
                          [@"⌃⌥⌘" stringByAppendingString:VibeShortcutKeyLabel(0, kCmd)]);
}

- (void)testTheAppsNamesFillWhatNoLayoutNames {
    XCTAssertEqualObjects(VibeShortcutDisplayString(kVibeShortcutNone), @"None");
    XCTAssertEqualObjects(VibeShortcutDisplayString(VibeShortcutMake(49, NSEventModifierFlagOption)), @"⌥Space");
    XCTAssertTrue([VibeShortcutKeyLabel(83, 0) hasPrefix:@"Keypad "], @"keypad 1");
    XCTAssertEqualObjects(VibeShortcutDisplayString(VibeShortcutMake(200, 0)), @"Key 200");
    XCTAssertNil(VibeShortcutKeyLabel(200, 0));
    XCTAssertEqualObjects(VibeShortcutKeyLabel(kVibeKeyCodeReturn, 0), @"↩");
}

- (void)testAShiftedKeyRidesInTheCharacterShiftTypes {
    NSEventModifierFlags mask = 0;
    NSString *letter = VibeShortcutKeyEquivalent(VibeShortcutMake(0, kCmd | NSEventModifierFlagShift), &mask);
    XCTAssertEqualObjects(letter, VibeShortcutKeyLabel(0, kCmd));
    XCTAssertEqual(mask, kCmd);
    XCTAssertEqualObjects(VibeShortcutKeyEquivalent(VibeShortcutMakeCharacter('o', kCmd), &mask), @"o");
    XCTAssertEqual(mask, kCmd);
    XCTAssertEqualObjects(VibeShortcutKeyEquivalent(VibeShortcutMake(kVibeKeyCodeDelete, NSEventModifierFlagShift),
                                                    &mask), @"\b");
    XCTAssertEqual(mask, NSEventModifierFlagShift, @"a special key keeps the flag");
    XCTAssertNil(VibeShortcutKeyEquivalent(kVibeShortcutNone, &mask));
    XCTAssertEqual(mask, 0u);
}

@end
