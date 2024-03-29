//
//  AccountHistory.h
//  iNodeMon
//
//  Created by David Symonds on 21/03/08.
//

#import <Cocoa/Cocoa.h>


@interface AccountHistory : NSObject {
	NSRecursiveLock *lock_;
	NSArray *usageData_;	// array of NSNumber
	NSCalendarDate *lastDate_;
}

- (void)setHistoryFromXMLNodes:(NSArray *)nodes;

// If you're going to use the following accessors, you should lock this object to get consistent data.
- (void)lock;
- (void)unlock;

@property (nonatomic, readonly) float max;
- (float)maxInLastDays:(int)numDaysAgo;
@property (nonatomic, readonly) int numDays;
@property (nonatomic, readonly, copy) NSCalendarDate *lastDate;
- (float)usageFrom:(int)numDaysAgo;

@end
