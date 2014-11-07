//
//  AccountStatus.h
//  iNodeMon
//
//  Created by David Symonds on 11/03/08.
//

#import <Cocoa/Cocoa.h>


@interface AccountStatus : NSObject {
	BOOL setQuota_, setDays_, setServiceInfo_;
	double quotaUsed_, quotaTotal_;	// in MB
	int daysLeft_;
	NSString *serviceInfo_;
}

// Expects "YYYY-MM-DD" format.
- (void)setRollover:(NSString *)rollover;
// Expects values in MB.
- (void)setQuotaUsed:(double)quotaUsed quotaTotal:(double)quotaTotal;
// Takes arbitrary string (usually "<speed> (<plan>)").
- (void)setServiceInfo:(NSString *)serviceInfo;


- (double)fractionOfQuotaLeft;
- (double)fractionOfTimeLeft;
- (double)quotaTotal;
- (int)daysLeft;
- (int)daysInPeriod;

// Bindable (or just bind to one of: "quota", "days")

// Suitable for menu use
- (NSString *)quotaUsedLongString;
- (NSString *)quotaTotalLongString;
- (NSString *)daysLeftLongString;
- (NSString *)serviceInfoLongString;

// Suitable for status bar item use
- (NSString *)quotaUsedPercentString;
- (NSString *)quotaLeftPercentString;
- (NSString *)daysUsedString;
- (NSString *)daysLeftString;
- (NSString *)daysUsedPercentString;
- (NSString *)daysLeftPercentString;

@end
