//
//  AccountHistory.m
//  iNodeMon
//
//  Created by David Symonds on 21/03/08.
//

#import "AccountHistory.h"


@implementation AccountHistory

+ (void)initialize
{
	[self exposeBinding:@"history"];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock_ = [[NSRecursiveLock alloc] init];
	usageData_ = [NSArray array];
	lastDate_ = [NSCalendarDate calendarDate];

	return self;
}


- (void)setHistoryFromXMLNodes:(NSArray *)nodes
{
	NSMutableArray *data = [NSMutableArray arrayWithCapacity:[nodes count]];

	NSEnumerator *en = [nodes objectEnumerator];
	NSXMLElement *node;
	NSCalendarDate *lastDate = nil;
	while ((node = [en nextObject])) {
		NSString *dateString = [[node attributeForName:@"day"] stringValue];
		NSCalendarDate *date = [NSCalendarDate dateWithString:dateString
						       calendarFormat:@"%Y-%m-%d"];
		NSString *traffic = [[[node nodesForXPath:@"traffic[@name='total']"
						    error:nil] lastObject] stringValue];
		NSNumber *amt = [NSNumber numberWithFloat:[traffic floatValue] / (1000*1000)];

		if (lastDate) {
			NSInteger delta;
			[date years:nil months:nil days:&delta
			      hours:nil minutes:nil seconds:nil sinceDate:lastDate];
			if (delta != 1) {
				// History data has gaps, which we interpret as absolutely zero usage.
				while (delta-- > 1)
					[data addObject:[NSNumber numberWithFloat:0]];
			}
		}

		lastDate = date;
		[data addObject:amt];
	}

#ifdef DEBUG
	NSLog(@"Loaded %lu days of usage history.", (unsigned long)[data count]);
#endif

	[self willChangeValueForKey:@"history"];
	[self lock];
	usageData_ = data;
	if (lastDate) {
		lastDate_ = lastDate;
	}
	[self unlock];
	[self didChangeValueForKey:@"history"];
}

- (void)lock
{
	[lock_ lock];
}

- (void)unlock
{
	[lock_ unlock];
}

#pragma mark -

- (float)max
{
	float max;

	[self lock];
	max = [self maxInLastDays:[self numDays]];
	[self unlock];

	return max;
}

- (float)maxInLastDays:(int)numDaysAgo
{
	float max = 0;

	[self lock];
	int index = [usageData_ count] - numDaysAgo - 1;
	if (index < 0)
		index = 0;
	NSNumber *n;
	for (; index < [usageData_ count]; ++index) {
		n = [usageData_ objectAtIndex:index];
		if (max < [n floatValue])
			max = [n floatValue];
	}
	[self unlock];

	return max;
}

- (int)numDays
{
	return [usageData_ count];
}

- (NSCalendarDate *)lastDate
{
	return lastDate_;
}

- (float)usageFrom:(int)numDaysAgo
{
	[self lock];
	float usage = 0.0;
	int index = [usageData_ count] - numDaysAgo - 1;
	if ((index >= 0) && (index < [usageData_ count]))
		usage = [[usageData_ objectAtIndex:index] floatValue];
	[self unlock];

	return usage;
}

@end
