//
//  UpdaterRulesTests.m
//
//  The updater's rules over values, and an unstarted updater's delegate
//  answers. Nothing starts an updater, so no feed is read and no setting is
//  written.
//

#import <XCTest/XCTest.h>

#import "UpdaterRules.h"
#import "VibeUpdater.h"

@interface UpdaterRulesTests : XCTestCase
@end

@implementation UpdaterRulesTests

static NSDate *UTCDate(NSString *iso) {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    return [formatter dateFromString:iso];
}

static NSArray<NSString *> *Keys(NSArray<NSDictionary<NSString *, NSString *> *> *parameters) {
    return [parameters valueForKey:@"key"];
}

- (void)testBetaUpdatesAllowTheBetaChannelOnly {
    XCTAssertEqualObjects(VibeUpdaterAllowedChannels(YES), [NSSet setWithObject:@"beta"]);
    XCTAssertEqualObjects(VibeUpdaterAllowedChannels(NO), [NSSet set]);
}

- (void)testIntervalReadsZeroWhileAutomaticChecksAreOff {
    XCTAssertEqual(VibeUpdaterCheckInterval(YES, 86400), 86400);
    XCTAssertEqual(VibeUpdaterCheckInterval(NO, 604800), 0);
}

- (void)testPeriodsAreTheUTCDayISOWeekAndMonth {
    NSArray *periods = VibeUpdaterCheckPeriods(UTCDate(@"2026-10-22T12:00:00Z"));
    XCTAssertEqualObjects(periods, (@[@"2026-10-22", @"2026-W43", @"2026-10"]));
}

- (void)testPeriodsFollowUTCNotTheLocalDay {
    // 23:30 in New York on the 22nd is the 23rd in UTC.
    NSArray *periods = VibeUpdaterCheckPeriods(UTCDate(@"2026-10-23T03:30:00Z"));
    XCTAssertEqualObjects(periods[0], @"2026-10-23");
}

- (void)testTheISOWeekCrossesTheYear {
    // 1 January 2027 is a Friday, so it is still in 2026's last ISO week.
    NSArray *periods = VibeUpdaterCheckPeriods(UTCDate(@"2027-01-01T08:00:00Z"));
    XCTAssertEqualObjects(periods, (@[@"2027-01-01", @"2026-W53", @"2027-01"]));
}

- (void)testAFirstCheckFlagsEveryPeriod {
    NSArray *parameters = VibeUpdaterFeedParameters(@"15.1", @"arm64", NO, @"de",
                                                    @[@"2026-10-22", @"2026-W43", @"2026-10"], nil);
    XCTAssertEqualObjects(Keys(parameters), (@[@"os", @"arch", @"channel", @"lang", @"d", @"w", @"m"]));
    XCTAssertEqualObjects(parameters[0][@"value"], @"15.1");
    XCTAssertEqualObjects(parameters[1][@"value"], @"arm64");
    XCTAssertEqualObjects(parameters[2][@"value"], @"stable");
    XCTAssertEqualObjects(parameters[3][@"value"], @"de");
    for (NSUInteger i = 4; i < parameters.count; i++) {
        XCTAssertEqualObjects(parameters[i][@"value"], @"1");
    }
}

- (void)testOnlyANewPeriodIsFlagged {
    NSArray *periods = @[@"2026-10-23", @"2026-W43", @"2026-10"];
    NSArray *sameWeek = VibeUpdaterFeedParameters(@"15.1", @"arm64", YES, @"en", periods,
                                                  @[@"2026-10-22", @"2026-W43", @"2026-10"]);
    XCTAssertEqualObjects(Keys(sameWeek), (@[@"os", @"arch", @"channel", @"lang", @"d"]));
    XCTAssertEqualObjects(sameWeek[2][@"value"], @"beta");

    NSArray *sameDay = VibeUpdaterFeedParameters(@"15.1", @"arm64", YES, @"en", periods, periods);
    XCTAssertEqualObjects(Keys(sameDay), (@[@"os", @"arch", @"channel", @"lang"]));
}

- (void)testAShortReportFlagsTheMissingPeriods {
    NSArray *parameters = VibeUpdaterFeedParameters(@"15.1", @"arm64", NO, @"en",
                                                    @[@"2026-10-22", @"2026-W43", @"2026-10"], @[@"2026-10-22"]);
    XCTAssertEqualObjects(Keys(parameters), (@[@"os", @"arch", @"channel", @"lang", @"w", @"m"]));
}

- (void)testAnUnstartedUpdaterAnswersWithTheAppsValues {
    __block BOOL beta = NO;
    VibeUpdater *host = [[VibeUpdater alloc] initWithFeedURLString:@"http://localhost:1/appcast.xml"
                                                       betaUpdates:^BOOL { return beta; }];
    SPUUpdater *updater = host.controller.updater;
    XCTAssertNotNil(updater);
    XCTAssertFalse(updater.sessionInProgress);
    XCTAssertEqualObjects([host feedURLStringForUpdater:updater], @"http://localhost:1/appcast.xml");
    XCTAssertEqualObjects([host allowedChannelsForUpdater:updater], [NSSet set]);
    beta = YES;
    XCTAssertEqualObjects([host allowedChannelsForUpdater:updater], [NSSet setWithObject:@"beta"]);
    NSArray *parameters = [host feedParametersForUpdater:updater sendingSystemProfile:NO];
    XCTAssertEqualObjects([Keys(parameters) subarrayWithRange:NSMakeRange(0, 4)],
                          (@[@"os", @"arch", @"channel", @"lang"]));
    XCTAssertEqualObjects(parameters[2][@"value"], @"beta");
}

- (void)testNoOverrideKeepsTheInfoPlistFeed {
    VibeUpdater *host = [[VibeUpdater alloc] initWithFeedURLString:nil betaUpdates:^BOOL { return NO; }];
    XCTAssertNil([host feedURLStringForUpdater:host.controller.updater]);
}

@end
