//
//  AccountStatus.m
//  iNodeMon
//
//  Created by David Symonds on 11/03/08.
//

#import "AccountStatus.h"


@interface AccountStatus (Private)

- (void)setDaysLeft:(int)daysLeft;

@end

#pragma mark -

@implementation AccountStatus

+ (NSSet*) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    static NSSet *keys = nil;
    if (keys == nil) {
        keys = [NSSet setWithObjects: @"daysLeftLongString",
                   @"daysUsedString", @"daysLeftString",
                   @"daysUsedPercentString", @"daysLeftPercentString", nil];
    }
    if ([keys containsObject: key]) {
        static NSSet *values = nil;
        if (values == nil) {
            values = [NSSet setWithObjects: @"quotaUsedLongString", @"quotaTotalLongString",
                                @"quotaUsedPercentString", @"quotaLeftPercentString", nil];
        }
        return values;
    } else if ([key isEqualToString: @"serviceInfo"]) {
        return [NSSet setWithObject: @"serviceInfoLongString"];
    }
    return nil;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	setQuota_ = setDays_ = setServiceInfo_ = NO;

	return self;
}

- (void)setQuotaUsed:(double)quotaUsed quotaTotal:(double)quotaTotal
{
	[self willChangeValueForKey:@"quota"];

	// TODO: sanity check
	// - quotaUsed, quotaTotal > 0
	quotaUsed_ = quotaUsed;
	quotaTotal_ = quotaTotal;
	setQuota_ = YES;

	[self didChangeValueForKey:@"quota"];
}

- (void)setDaysLeft:(int)daysLeft
{
	[self willChangeValueForKey:@"days"];

	// TODO: sanity check
	// - daysLeft > 0
	daysLeft_ = daysLeft;
	setDays_ = YES;

	[self didChangeValueForKey:@"days"];
}

- (void)setServiceInfo:(NSString *)serviceInfo
{
	[self willChangeValueForKey:@"serviceInfo"];

	serviceInfo_ = serviceInfo;
	setServiceInfo_ = YES;

	[self didChangeValueForKey:@"serviceInfo"];
}

- (void)setRollover:(NSString *)rollover
{
	NSCalendarDate *date = [NSCalendarDate dateWithString:rollover calendarFormat:@"%Y-%m-%d"];
	if (!date) {
		NSLog(@"ERROR: Rollover date in bad format: %@", rollover);
		return;
	}
	int daysLeft = [date dayOfCommonEra] - [[NSCalendarDate calendarDate] dayOfCommonEra];
	[self setDaysLeft:daysLeft];
}

#pragma mark -

- (double)fractionOfQuotaLeft
{
	if (!setQuota_)
		return 0;
	return (quotaTotal_ - quotaUsed_) / quotaTotal_;
}

- (double)fractionOfTimeLeft
{
	if (!setDays_)
		return 0;
	double total = [self daysInPeriod];
	return daysLeft_ / total;
}

- (double)quotaTotal
{
	if (!setQuota_)
		return 0;
	return quotaTotal_;
}

- (int)daysLeft
{
	if (!setDays_)
		return 0;
	return daysLeft_;
}

- (int)daysInPeriod
{
	// The number of days in the current period is the number of days in the
	// month *previous* to the period's end date, because that's the end-of-month
	// that is in this period. We are assuming that the periods start/end on the
	// same *day* of each month (e.g. the 7th).
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *startDelta = [[NSDateComponents alloc] init];
	[startDelta setDay:[self daysLeft]];  // go to end of period
	[startDelta setMonth:-1];             // ... and then back a month
	NSDate *startDate = [calendar dateByAddingComponents:startDelta toDate:[NSDate date] options:0];
	int num = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:startDate].length;
	return num;
}

- (NSString *)quotaUsedLongString
{
	if (!setQuota_)
		return @"Used: ?";
	return [NSString stringWithFormat:@"Used: %.1f MB (%.1f%%)",
		quotaUsed_, quotaUsed_ / quotaTotal_ * 100];
}

- (NSString *)quotaTotalLongString
{
	if (!setQuota_)
		return @"Total: ?";
	return [NSString stringWithFormat:@"Total: %.0f MB", quotaTotal_];
}

- (NSString *)daysLeftLongString
{
	if (!setDays_)
		return @"?";
	return [NSString stringWithFormat:@"%d day%s until rollover",
		daysLeft_, daysLeft_ != 1 ? "s" : ""];
}

- (NSString *)serviceInfoLongString
{
	if (!setServiceInfo_)
		return @"?";
	return serviceInfo_;
}

#pragma mark -

- (NSString *)quotaUsedPercentString
{
	if (!setQuota_)
		return @"?%";
	return [NSString stringWithFormat:@"%.1f%%", 100.0 * quotaUsed_ / quotaTotal_];
}

- (NSString *)quotaLeftPercentString
{
	if (!setQuota_)
		return @"?%";
	return [NSString stringWithFormat:@"%.1f%%", 100.0 * (quotaTotal_ - quotaUsed_) / quotaTotal_];
}

- (NSString *)daysUsedString
{
	if (!setDays_)
		return @"?d";
	return [NSString stringWithFormat:@"%dd", [self daysInPeriod] - daysLeft_];
}

- (NSString *)daysLeftString
{
	if (!setDays_)
		return @"?d";
	return [NSString stringWithFormat:@"%dd", daysLeft_];
}

- (NSString *)daysUsedPercentString
{
	if (!setDays_)
		return @"?%";
	return [NSString stringWithFormat:@"%.0f%%", 100.0 * ([self daysInPeriod] - daysLeft_) / [self daysInPeriod]];
}

- (NSString *)daysLeftPercentString
{
	if (!setDays_)
		return @"?%";
	return [NSString stringWithFormat:@"%.0f%%", 100.0 * daysLeft_ / [self daysInPeriod]];
}

@end
