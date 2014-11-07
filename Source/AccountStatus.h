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


@property (nonatomic, readonly) double fractionOfQuotaLeft;
@property (nonatomic, readonly) double fractionOfTimeLeft;
@property (nonatomic, readonly) double quotaTotal;
@property (nonatomic, readonly) int daysLeft;
@property (nonatomic, readonly) int daysInPeriod;

// Bindable (or just bind to one of: "quota", "days")

// Suitable for menu use
@property (nonatomic, readonly, copy) NSString *quotaUsedLongString;
@property (nonatomic, readonly, copy) NSString *quotaTotalLongString;
@property (nonatomic, readonly, copy) NSString *daysLeftLongString;
@property (nonatomic, readonly, copy) NSString *serviceInfoLongString;

// Suitable for status bar item use
@property (nonatomic, readonly, copy) NSString *quotaUsedPercentString;
@property (nonatomic, readonly, copy) NSString *quotaLeftPercentString;
@property (nonatomic, readonly, copy) NSString *daysUsedString;
@property (nonatomic, readonly, copy) NSString *daysLeftString;
@property (nonatomic, readonly, copy) NSString *daysUsedPercentString;
@property (nonatomic, readonly, copy) NSString *daysLeftPercentString;

@end
