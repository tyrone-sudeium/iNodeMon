//
//  Triggers.m
//  iNodeMon
//
//  Created by David Symonds on 4/4/08.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "Triggers.h"


#pragma mark C callbacks

static void ipChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
	NSInvocation *inv = (NSInvocation *) info;

	// NSInvocation is a bit weird. The actual arguments that are passed to the method
	// start at 2, since 0 and 1 are reserved for self and _cmd, respectively.
	NSString *type = @"IP";
	[inv setArgument:&type atIndex:2];
	[inv invoke];
}

#pragma mark Relay object

// This has memory leaks galore, but the object will last as long as the application.

@interface TriggerRelay : NSObject {
	NSInvocation *invocation_;
	NSString *type_;
}
@end

@implementation TriggerRelay

- (id)initWithTarget:(NSObject *)target selector:(SEL)selector type:(NSString *)type
{
	if (!(self = [super init]))
		return nil;

	NSMethodSignature *sig = [target methodSignatureForSelector:selector];
	invocation_ = [[NSInvocation invocationWithMethodSignature:sig] retain];
	[invocation_ setTarget:target];
	[invocation_ setSelector:selector];
	type_ = [type retain];

	return self;
}

- (void)trigger:(id)arg
{
	[invocation_ setArgument:&type_ atIndex:2];
	[invocation_ invoke];
}

@end

#pragma mark -

@implementation Triggers

+ (void)registerForIPChangeTrigger:(NSObject *)targetObject selector:(SEL)selector
{
	// Record callback as an NSInvocation
	NSMethodSignature *sig = [targetObject methodSignatureForSelector:selector];
	NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setTarget:targetObject];
	[inv setSelector:selector];

	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = [inv retain];
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;

	SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("iNodeMon"), ipChange, &ctxt);
	CFRunLoopSourceRef runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
	NSArray *keys = [NSArray arrayWithObject:@"State:/Network/Global/IPv4"];
	SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
#ifdef DEBUG
	NSLog(@"Registered for changes to SystemConfiguration keys: %@", keys);
#endif
}

+ (void)registerForWakeTrigger:(NSObject *)targetObject selector:(SEL)selector
{
	TriggerRelay *obj = [[TriggerRelay alloc] initWithTarget:targetObject selector:selector type:@"Wake"];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:obj
							       selector:@selector(trigger:)
								   name:NSWorkspaceDidWakeNotification
								 object:nil];
#ifdef DEBUG
	NSLog(@"Registered for wake");
#endif
}

@end
