//
//  AccountStatusTest.m
//  iNodeMon
//
//  Created by David Symonds on 3/20/08.
//

#import "AccountStatus.h"
#import "AccountStatusTest.h"


@implementation AccountStatusTest

- (void)setUp
{
	as_ = [[AccountStatus alloc] init];
}

- (void)tearDown
{
	[as_ release];
	as_ = nil;
}

- (NSString *)dateStamp:(int)daysInFuture
{
	return [[[NSCalendarDate calendarDate]
		 dateByAddingYears:0 months:0 days:daysInFuture hours:0 minutes:0 seconds:0]
		descriptionWithCalendarFormat:@"%Y-%m-%d"];
}

- (void)testInitialState
{
	STAssertNotNil(as_, @"Couldn't create AccountStatus object.");
	STAssertEqualObjects([as_ quotaUsedPercentString], @"?%", nil);
	STAssertEqualObjects([as_ daysLeftString], @"?d", nil);
}

- (void)testSimple1
{
	// To compensate for differences between month length (28-31 days), we allow 0.1 error
	// in time fraction.
	// TODO: Make these more rigorous tests.

	[as_ setRollover:[self dateStamp:28]];
	[as_ setQuotaUsed:0 quotaTotal:200];
	STAssertEqualsWithAccuracy([as_ fractionOfQuotaLeft], 1.0, 1e-8, nil);
	STAssertEqualsWithAccuracy([as_ fractionOfTimeLeft], 1.0, 0.1, nil);
	STAssertEquals([as_ daysLeft], 28, nil);

	[as_ setRollover:[self dateStamp:15]];
	[as_ setQuotaUsed:50 quotaTotal:200];
	STAssertEqualsWithAccuracy([as_ fractionOfQuotaLeft], 0.75, 1e-8, nil);
	STAssertEqualsWithAccuracy([as_ fractionOfTimeLeft], 0.5, 0.1, nil);
	STAssertEquals([as_ daysLeft], 15, nil);

	[as_ setRollover:[self dateStamp:3]];
	[as_ setQuotaUsed:180 quotaTotal:200];
	STAssertEqualsWithAccuracy([as_ fractionOfQuotaLeft], 0.1, 1e-8, nil);
	STAssertEqualsWithAccuracy([as_ fractionOfTimeLeft], 0.1, 0.1, nil);
	STAssertEquals([as_ daysLeft], 3, nil);
}

@end
