//
//  SettingsPanesWindowControllerTests.m
//  SettingsWindowTests
//
//  The generic window over two panes, never shown: the sidebar drives the
//  selection, the title follows the pane, Back and Forward walk the history,
//  and the search narrows the sidebar.
//

#import <XCTest/XCTest.h>
#import "DrawnControls.h"
#import "SettingsPanesWindowController.h"
#import "SettingsPaneViewController.h"
#import "SettingsSidebarController.h"
#import "VibeDetentSlider.h"

// A pane of one titled row around one control.
@interface SettingsTestPane : SettingsPaneViewController
@property (nonatomic, copy) NSString *rowTitle;
@property (nonatomic, strong) NSView *control;
@end

@implementation SettingsTestPane

- (void)loadView {
    SettingsRowView *row = [SettingsRowView rowWithTitle:self.rowTitle control:self.control];
    [self loadPaneWithSections:@[[SettingsSectionView sectionWithRows:@[row]]]];
}

@end

@interface SettingsPanesWindowControllerTests : XCTestCase
@end

@implementation SettingsPanesWindowControllerTests {
    SettingsPanesWindowController *_controller;
    NSMutableArray<NSNumber *> *_effects;
}

- (SettingsTestPane *)paneWithRowTitle:(NSString *)title control:(NSView *)control {
    NSMutableArray<NSNumber *> *effects = _effects;
    SettingsTestPane *pane = [[SettingsTestPane alloc] initWithEffectsSink:^(NSUInteger bits) {
        [effects addObject:@(bits)];
    }];
    pane.rowTitle = title;
    pane.control = control;
    return pane;
}

- (void)setUp {
    _effects = [NSMutableArray array];
    NSTabViewItem *general = [SettingsPanesWindowController
            paneItemWithViewController:[self paneWithRowTitle:@"Dark mode" control:[[VibeSwitch alloc] init]]
                            identifier:@"general" label:@"General" symbolName:@"gearshape"];
    NSTabViewItem *sound = [SettingsPanesWindowController
            paneItemWithViewController:[self paneWithRowTitle:@"Volume" control:[[VibeDetentSlider alloc] init]]
                            identifier:@"sound" label:@"Sound" symbolName:@"speaker.wave.2"];
    _controller = [[SettingsPanesWindowController alloc]
            initWithPaneGroups:@[@[general], @[sound]]
                     backTitle:@"Back" forwardTitle:@"Forward" undoTitle:@"Undo" redoTitle:@"Redo"
             searchPlaceholder:@"Search" noResultsText:@"No Results"];
}

- (void)tearDown {
    [_controller.window close];
    _controller = nil;
}

- (SettingsSidebarController *)sidebar {
    NSSplitViewController *split = (NSSplitViewController *)_controller.window.contentViewController;
    return (SettingsSidebarController *)split.splitViewItems.firstObject.viewController;
}

- (void)testTheFirstPaneOpensSelectedAndTitled {
    XCTAssertEqualObjects(_controller.selectedTabItem.identifier, @"general");
    XCTAssertEqualObjects(_controller.window.title, @"General");
    XCTAssertEqualObjects(_controller.currentLocation, @"general");
    XCTAssertFalse([_controller canNavigateForward:NO]);
    XCTAssertFalse([_controller canNavigateForward:YES]);
    XCTAssertFalse(_controller.window.isVisible);
}

- (void)testTheSidebarGroupsPanesWithASpacer {
    // General, the spacer before Sound's group, and Sound.
    XCTAssertEqual(self.sidebar.tableView.numberOfRows, 3);
    XCTAssertEqualObjects(self.sidebar.visiblePaneIdentifiers, (@[@"general", @"sound"]));
}

- (void)testPickingASidebarRowSelectsItsPane {
    [self.sidebar.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
    XCTAssertEqualObjects(_controller.selectedTabItem.identifier, @"sound");
    XCTAssertEqualObjects(_controller.window.title, @"Sound");
    XCTAssertTrue([_controller canNavigateForward:NO]);
}

- (void)testBackAndForwardWalkTheHistory {
    [self.sidebar.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
    [_controller navigateForward:NO];
    XCTAssertEqualObjects(_controller.selectedTabItem.identifier, @"general");
    XCTAssertEqual(self.sidebar.tableView.selectedRow, 0);
    XCTAssertTrue([_controller canNavigateForward:YES]);
    [_controller navigateForward:YES];
    XCTAssertEqualObjects(_controller.selectedTabItem.identifier, @"sound");
    XCTAssertFalse([_controller canNavigateForward:YES]);
}

- (void)testSearchNarrowsTheSidebarToMatchingPanes {
    XCTAssertEqualObjects([_controller searchSettingsFor:@"volume"], @[@"sound"]);
    XCTAssertEqualObjects(_controller.selectedTabItem.identifier, @"sound");
    XCTAssertEqualObjects([_controller searchSettingsFor:@"general"], @[@"general"]);
    XCTAssertEqualObjects([_controller searchSettingsFor:@"nothing here"], @[]);
    XCTAssertEqualObjects([_controller searchSettingsFor:@""], (@[@"general", @"sound"]));
}

- (void)testAPaneRequestsEffectsThroughItsSink {
    SettingsPaneViewController *pane =
            (SettingsPaneViewController *)[_controller tabItemWithIdentifier:@"sound"].viewController;
    [pane applyLiveEffects:5];
    XCTAssertEqualObjects(_effects, @[@5]);
}

- (void)testEveryPaneSharesOneSize {
    NSSize general = ((SettingsPaneViewController *)
            [_controller tabItemWithIdentifier:@"general"].viewController).sharedPaneSize;
    NSSize sound = ((SettingsPaneViewController *)
            [_controller tabItemWithIdentifier:@"sound"].viewController).sharedPaneSize;
    XCTAssertTrue(NSEqualSizes(general, sound));
    XCTAssertGreaterThanOrEqual(general.width, kSettingsPaneWidth);
    XCTAssertGreaterThanOrEqual(general.height, kSettingsPaneMinHeight);
}

@end
