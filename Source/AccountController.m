//
//  AccountController.m
//  iNodeMon
//
//  Created by David Symonds on 12/10/08.
//

#import "AccountController.h"
#import "AccountHistory.h"
#import "AccountStatus.h"
#import "EMKeychainItem.h"
#import "EMKeychainProxy.h"
#import "InternodeApiFetcher.h"


@interface AccountController (Private)

- (void)waitForUpdateCompletionInThread:(id)sender;
- (void)updateSemaphoreDown;

- (EMGenericKeychainItem *)keychainItem;
//- (NSString *)doQuery:(NSString *)query;

@end

#pragma mark -

@implementation AccountController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	accountStatus_ = [[AccountStatus alloc] init];
	accountHistory_ = [[AccountHistory alloc] init];

	updateLock_ = [[NSLock alloc] init];
	lastUpdateOfQuota_ = [[NSDate distantPast] retain];
	lastUpdateOfServiceInfo_ = [[NSDate distantPast] retain];
	lastUpdateOfHistory_ = [[NSDate distantPast] retain];

	// Set up KVO
	[accountStatus_ addObserver:self forKeyPath:@"quota" options:0 context:nil];
	[accountStatus_ addObserver:self forKeyPath:@"days" options:0 context:nil];
	[accountStatus_ addObserver:self forKeyPath:@"serviceInfo" options:0 context:nil];
	[accountHistory_ addObserver:self forKeyPath:@"history" options:0 context:nil];

	return self;
}

- (void)dealloc
{
	[accountStatus_ release];
	[accountHistory_ release];

	[updateLock_ release];
	[lastUpdateOfQuota_ release];
	[lastUpdateOfServiceInfo_ release];
	[lastUpdateOfHistory_ release];

	[super dealloc];
}

#pragma mark -

// Copied out of PrefsController.m.
// TODO: Factor these mechanics somewhere better.
- (EMGenericKeychainItem *)keychainItem
{
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
	if (!username)
		return nil;
	return [[EMKeychainProxy sharedProxy] genericKeychainItemForService:@"iNodeMon" withUsername:username];
}

#pragma mark -

- (void)handleServiceIdResponse:(NSDictionary *)result
{
	NSError *error = [result valueForKey:@"error"];
	if (error) {
		NSLog(@"Failed getting service ID: %@", [error localizedDescription]);
		[self updateSemaphoreDown];
		return;
	}

	NSXMLDocument *doc = [result valueForKey:@"document"];
	NSArray *services = [doc nodesForXPath:@"//internode/api/services/service[@type='Personal_ADSL']"
					 error:nil];
	if ([services count] == 0) {
		NSLog(@"Woah. No services found. Doc is %@", doc);
		[self updateSemaphoreDown];
		return;
	}

	serviceId_ = [[[services objectAtIndex:0] stringValue] retain];

	reupdateImmediately_ = YES;
	[self updateSemaphoreDown];
}

- (void)handleServiceInfoResponse:(NSDictionary *)result
{
	NSError *error = [result valueForKey:@"error"];
	if (error) {
		NSLog(@"Failed getting service info: %@", [error localizedDescription]);
		[self updateSemaphoreDown];
		return;
	}

	NSXMLDocument *doc = [result valueForKey:@"document"];

	NSString *plan = [[[doc nodesForXPath:@"//internode/api/service/plan" error:nil] lastObject] stringValue];
	NSString *speed = [[[doc nodesForXPath:@"//internode/api/service/speed" error:nil] lastObject] stringValue];

	[accountStatus_ setServiceInfo:[NSString stringWithFormat:@"%@ (%@)", speed, plan]];

	[lastUpdateOfServiceInfo_ autorelease];
	lastUpdateOfServiceInfo_ = [[NSDate date] retain];
	[self updateSemaphoreDown];
}

- (void)handleUsageResponse:(NSDictionary *)result
{
	NSError *error = [result valueForKey:@"error"];
	if (error) {
		NSLog(@"Failed getting usage: %@", [error localizedDescription]);
		[self updateSemaphoreDown];
		return;
	}

	NSXMLDocument *doc = [result valueForKey:@"document"];
	NSXMLElement *node = [[doc nodesForXPath:@"//internode/api/traffic[@name='total']"
					   error:nil] objectAtIndex:0];
#ifdef DEBUG
	NSLog(@"Usage node: %@", node);
#endif
	// attributes:
	//	rollover (YYYY-MM-DD)
	//	plan-interval (Monthly or Quarterly)
	//	quota (in bytes)
	//	unit = "bytes"

	// Sanity check
	NSString *rolloverStr = [[node attributeForName:@"rollover"] stringValue];
	NSString *quotaTotalStr = [[node attributeForName:@"quota"] stringValue];
	NSString *quotaUsedStr = [[node childAtIndex:0] stringValue];
	if (!node || !rolloverStr || !quotaTotalStr || !quotaUsedStr) {
		NSLog(@"Malformed document returned for usage request: %@", doc);
		[self updateSemaphoreDown];
		return;
	}

	[accountStatus_ setRollover:rolloverStr];

	double quotaUsed = [quotaUsedStr doubleValue] / (1000*1000);
	double quotaTotal = [quotaTotalStr doubleValue] / (1000*1000);
	[accountStatus_ setQuotaUsed:quotaUsed quotaTotal:quotaTotal];

	[lastUpdateOfQuota_ autorelease];
	lastUpdateOfQuota_ = [[NSDate date] retain];
	[self updateSemaphoreDown];
}

- (void)handleHistoryResponse:(NSDictionary *)result
{
	NSError *error = [result valueForKey:@"error"];
	if (error) {
		NSLog(@"Failed getting history: %@", [error localizedDescription]);
		[self updateSemaphoreDown];
		return;
	}

	NSXMLDocument *doc = [result valueForKey:@"document"];
	NSArray *nodes = [doc nodesForXPath:@"//internode/api/usagelist/usage"
				      error:nil];
	[accountHistory_ setHistoryFromXMLNodes:nodes];

	[lastUpdateOfHistory_ autorelease];
	lastUpdateOfHistory_ = [[NSDate date] retain];
	[self updateSemaphoreDown];
}

- (void)waitForUpdateCompletionInThread:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[semaphoreCondition_ lockWhenCondition:0];
	[semaphoreCondition_ unlock];
	[semaphoreCondition_ release];

#ifdef DEBUG
	NSLog(@"Updates all complete!");
#endif

	// -unlock must be called from the same thread as -lock.
	// Only notify observers if we're not about to continue updating.
        if (!reupdateImmediately_)
		[self willChangeValueForKey:@"isUpdating"];
	[updateLock_ performSelectorOnMainThread:@selector(unlock) withObject:nil waitUntilDone:YES];
        if (!reupdateImmediately_)
		[self didChangeValueForKey:@"isUpdating"];

	if (reupdateImmediately_) {
		[self performSelectorOnMainThread:@selector(update)
				       withObject:nil
				    waitUntilDone:NO];
	}

	[pool release];
}

- (void)updateSemaphoreDown
{
	[semaphoreCondition_ lock];
	if (semaphore_ > 0)
		--semaphore_;
	[semaphoreCondition_ unlockWithCondition:(semaphore_ > 0) ? 1 : 0];
}

- (void)update
{
	if (![updateLock_ tryLock]) {
#ifdef DEBUG
		NSLog(@"update already in progress");
#endif
		return;		// Update already in progress
	}
#ifdef DEBUG
	NSLog(@"doing update");
#endif
	[self willChangeValueForKey:@"isUpdating"];
	[self didChangeValueForKey:@"isUpdating"];

	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSTimeInterval quotaInterval = [[infoDict valueForKey:@"InternodeUpdateIntervalQuota"] intValue];
	NSTimeInterval serviceInfoInterval = [[infoDict valueForKey:@"InternodeUpdateIntervalServiceInfo"] intValue];
	NSTimeInterval historyInterval = [[infoDict valueForKey:@"InternodeUpdateIntervalHistory"] intValue];

#ifndef DEBUG
	// Restrict all time intervals to be at least 1 hour (3600 seconds)
	if (quotaInterval < 3600)
		quotaInterval = 3600;
	if (serviceInfoInterval < 3600)
		serviceInfoInterval = 3600;
	if (historyInterval < 3600)
		historyInterval = 3600;
#endif

	semaphoreCondition_ = [[NSConditionLock alloc] initWithCondition:1];
	[semaphoreCondition_ lock];
	semaphore_ = 1;
	reupdateImmediately_ = NO;
	[NSThread detachNewThreadSelector:@selector(waitForUpdateCompletionInThread:)
				 toTarget:self
			       withObject:nil];

	// SERVICE_ID
	BOOL hasServiceId = serviceId_ != nil;
	if (!hasServiceId) {
		[InternodeApiFetcher fetchPath:@"/"
					object:self
				      selector:@selector(handleServiceIdResponse:)];
		++semaphore_;
	}

	if (hasServiceId && -[lastUpdateOfQuota_ timeIntervalSinceNow] >= quotaInterval) {
		// Time to update quota
		NSString *path = [NSString stringWithFormat:@"/%@/usage", serviceId_];
		[InternodeApiFetcher fetchPath:path
					object:self
				      selector:@selector(handleUsageResponse:)];
		++semaphore_;
	}

	if (hasServiceId && -[lastUpdateOfServiceInfo_ timeIntervalSinceNow] >= serviceInfoInterval) {
		// Time to update service info (should be rare, except on startup)
		NSString *path = [NSString stringWithFormat:@"/%@/service", serviceId_];
		[InternodeApiFetcher fetchPath:path
					object:self
				      selector:@selector(handleServiceInfoResponse:)];
		++semaphore_;
	}

	if (hasServiceId && -[lastUpdateOfHistory_ timeIntervalSinceNow] >= historyInterval) {
		// Time to update history (should be somewhat rare, except on startup)
		// TODO: This only gets one year's worth. Get more?
		NSString *path = [NSString stringWithFormat:@"/%@/history", serviceId_];
		[InternodeApiFetcher fetchPath:path
					object:self
				      selector:@selector(handleHistoryResponse:)];
		++semaphore_;
	}

	[semaphoreCondition_ unlockWithCondition:1];
	[self updateSemaphoreDown];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
#ifdef DEBUG
	NSLog(@"%@: Was notified of change of '%@' on %@", [self class], keyPath, object);
#endif
	// FIXME: Is there a better way to do this?
	if (object == accountStatus_) {
		[self willChangeValueForKey:@"accountStatus"];
		[self didChangeValueForKey:@"accountStatus"];
	}
	if (object == accountHistory_) {
		[self willChangeValueForKey:@"accountHistory"];
		[self didChangeValueForKey:@"accountHistory"];
	}
}

#pragma mark -
#pragma mark Bindings

- (AccountStatus *)accountStatus
{
	return accountStatus_;
}

- (AccountHistory *)accountHistory
{
	return accountHistory_;
}

- (BOOL)isUpdating
{
	if ([updateLock_ tryLock]) {
		[updateLock_ unlock];
		return NO;
	}
	return YES;
}

@end
