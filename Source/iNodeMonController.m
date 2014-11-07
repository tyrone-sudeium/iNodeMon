//
//  iNodeMonController.m
//  iNodeMon
//
//  Created by David Symonds on 25/01/07.
//

#import "AccountController.h"
#import "AccountHistory.h"
#import "AccountStatus.h"
#import "EMKeychainItem.h"
#import "HistoryGraph.h"
#import "iNodeMonController.h"
#import "PrefsController.h"
#import "Triggers.h"


@interface iNodeMonController (Private)

- (void)userDefaultsChanged:(NSNotification *)notification;

- (void)considerTriggeredUpdate:(NSString *)type;

@end

#pragma mark -

@implementation iNodeMonController

+ (void)initialize
{
	NSMutableDictionary *appDefaults = [NSMutableDictionary dictionary];

	// Default display options
	[appDefaults setValue:@"quotaUsedPercent" forKey:@"StatusTextOptionUpper"];
	[appDefaults setValue:@"daysLeft" forKey:@"StatusTextOptionLower"];
	[appDefaults setValue:[NSNumber numberWithInt:30] forKey:@"NumDaysOfHistory"];

	// Default colour options
	[appDefaults setValue:[NSArchiver archivedDataWithRootObject:[NSColor redColor]]
		       forKey:@"StatusTextColourLow"];
	[appDefaults setValue:[NSArchiver archivedDataWithRootObject:[NSColor orangeColor]]
		       forKey:@"StatusTextColourAhead"];
	[appDefaults setValue:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]]
		       forKey:@"StatusTextColourOk"];

	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"SUEnableAutomaticChecks"];

	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

// Load a named image, and scale it to be suitable for menu bar use.
- (NSImage *)prepareImageForMenubar:(NSString *)name
{
	NSImage *img = [NSImage imageNamed:name];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(18, 18)];

	return img;
}

- (NSString *)renderStatusText:(NSString *)variable
{
	if ([variable isEqualToString:@"nothing"])
		return @"";

	NSString *selName = [variable stringByAppendingString:@"String"];
	SEL sel = sel_registerName([selName cStringUsingEncoding:NSMacOSRomanStringEncoding]);

	AccountStatus *status = [accountController_ accountStatus];
	if ([status respondsToSelector:sel])
		return [status performSelector:sel];
	else
		return @"???";
}

- (void)updateStatusItem
{
	// The variables will be things like "quotaUsedPercent".
	NSString *var1 = [[NSUserDefaults standardUserDefaults] valueForKey:@"StatusTextOptionUpper"];
	NSString *var2 = [[NSUserDefaults standardUserDefaults] valueForKey:@"StatusTextOptionLower"];

	if ([var1 isEqualToString:@"nothing"] && [var2 isEqualToString:@"nothing"]) {
		[statusItem setTitle:@""];
		return;
	}
	NSString *str = [NSString stringWithFormat:@"%@\n%@",
		[self renderStatusText:var1], [self renderStatusText:var2]];

	NSColor *lowColour = [NSUnarchiver unarchiveObjectWithData:
		[[NSUserDefaults standardUserDefaults] dataForKey:@"StatusTextColourLow"]];
	NSColor *aheadColour = [NSUnarchiver unarchiveObjectWithData:
		[[NSUserDefaults standardUserDefaults] dataForKey:@"StatusTextColourAhead"]];
	NSColor *okColour = [NSUnarchiver unarchiveObjectWithData:
		[[NSUserDefaults standardUserDefaults] dataForKey:@"StatusTextColourOk"]];

	// If there's less than 5% of the quota left, show text in red.
	// If the quota used (%) is more than the time elapsed (%), show text in orange.
	NSColor *textColour = okColour;
	AccountStatus *status = [accountController_ accountStatus];
	if ([status fractionOfQuotaLeft] <= 0.05)
		textColour = lowColour;
	else if (([status fractionOfQuotaLeft] < [status fractionOfTimeLeft]) &&
		 ([status daysLeft] < [status daysInPeriod]))
		textColour = aheadColour;

	float sbHeight = [[NSStatusBar systemStatusBar] thickness];
	float fontHeight = (sbHeight - 4) / 2;		// Enough for two lines, plus spacing
	NSFont *font = [NSFont menuBarFontOfSize:fontHeight];

	NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
		font, NSFontAttributeName, textColour, NSForegroundColorAttributeName, nil];
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:str attributes:attrs];
	[statusItem setAttributedTitle:as];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	accountController_ = [[AccountController alloc] init];

	imageIdle = [self prepareImageForMenubar:@"inode_icon_grey"];
	imageActive = [self prepareImageForMenubar:@"inode_icon_orange"];

	return self;
}


- (void)openQuickLink:(id)sender
{
	NSURL *url = [NSURL URLWithString:[sender representedObject]];
#ifdef DEBUG
	NSLog(@"Opening quick link to %@", [url absoluteString]);
#endif

	if (![[NSWorkspace sharedWorkspace] openURL:url])
		NSBeep();
}

- (void)buildQuickLinksMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	NSArray *quickLinks = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"InternodeQuickLinks"];
	NSEnumerator *en = [quickLinks objectEnumerator];
	NSDictionary *link;
	while ((link = [en nextObject])) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:[link valueForKey:@"Title"]];
		[item setRepresentedObject:[link valueForKey:@"URL"]];
		[item setTarget:self];
		[item setAction:@selector(openQuickLink:)];
		[menu addItem:item];
	}

	[quickLinksMenuItem setSubmenu:menu];
	[quickLinksMenuItem setEnabled:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	if (object == accountController_) {
		if ([keyPath isEqualToString:@"accountStatus"]) {
			[self updateStatusItem];
		} else if ([keyPath isEqualToString:@"isUpdating"]) {
			// Adjust status item image
			BOOL isUpdating = [accountController_ isUpdating];
			[statusItem setImage:(isUpdating ? imageActive : imageIdle)];
		}
	}
}

- (void)awakeFromNib
{
	NSStatusBar *sb;

	sb = [NSStatusBar systemStatusBar];

	statusItem = [sb statusItemWithLength:NSVariableStatusItemLength];
	[statusItem setHighlightMode:YES];
	[statusItem setImage:imageIdle];
	[statusItem setMenu:statusbarMenu];

	[accountController_ addObserver:self forKeyPath:@"accountStatus" options:0 context:nil];
	[accountController_ addObserver:self forKeyPath:@"isUpdating" options:0 context:nil];

	// Cosmetic fix for OS X 10.5 (Leopard): NSMenuItem has changed such that
	// menu items are no longer disabled (greyed out) when they have no target.
	// Since IB 2.5 (Tiger's version) doesn't allow you to explicitly disable
	// menu items, I do it here.
	NSEnumerator *en = [[statusbarMenu itemArray] objectEnumerator];
	NSMenuItem *item;
	while ((item = [en nextObject])) {
		if (![item target])
			[item setEnabled:NO];
	}

	[self buildQuickLinksMenu];

	// Populate display options
	[displayOptionsController addObjects:
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"nothing", @"parameter",
				@"Nothing", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"quotaUsedPercent", @"parameter",
				@"Quota Used (%)", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"quotaLeftPercent", @"parameter",
				@"Quota Left (%)", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"daysUsed", @"parameter",
				@"Days Used", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"daysLeft", @"parameter",
				@"Days Left", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"daysUsedPercent", @"parameter",
				@"Days Used (%)", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"daysLeftPercent", @"parameter",
				@"Days Left (%)", @"description", nil],
			nil]];

	// Populate history periods
	[historyPeriodsController addObjects:
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:30], @"numDays",
				@"30 days", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:60], @"numDays",
				@"60 days", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:90], @"numDays",
				@"90 days", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:365], @"numDays",
				@"1 year", @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:1e6], @"numDays",
				@"All", @"description", nil],
			nil]];

	// If our preferences change (esp. display prefs), we might need to immediately update things.
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(userDefaultsChanged:)
						     name:NSUserDefaultsDidChangeNotification
						   object:nil];

	// Register for various triggers
    [Triggers setIPChangedBlock:^{
        [self considerTriggeredUpdate: @"IP"];
    }];
    [Triggers setWakeBlock:^{
        [self considerTriggeredUpdate: @"Wake"];
    }];

	// Schedule a recurring timer (every 15 minutes),
	// and also schedule a one-off timer (in 2s) to get initial data.
	updatingTimer = [NSTimer scheduledTimerWithTimeInterval:(15 * 60) target:self
				       selector:@selector(doUpdate:) userInfo:nil repeats:YES];
	[NSTimer scheduledTimerWithTimeInterval:2 target:self
				       selector:@selector(doUpdate:) userInfo:nil repeats:NO];

	// Ugh. This should not be here.
	[historyGraph setAccountController:accountController_];

	[NSApp unhide];
}

- (void)doUpdate:(id)sender
{
	[accountController_ update];
}

- (IBAction)doAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanelWithOptions:
		[NSDictionary dictionaryWithObject:@"" forKey:@"Version"]];
}

- (IBAction)doPreferences:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow center];
	[prefsWindow makeKeyAndOrderFront:sender];
}

- (IBAction)doHistory:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[historyWindow center];
	[historyWindow makeKeyAndOrderFront:sender];
}

#pragma mark -

- (void)userDefaultsChanged:(NSNotification *)notification
{
	// TODO: Make this more selective, so we don't always update the status item.
	[self updateStatusItem];
}

#pragma mark -

- (void)considerTriggeredUpdate:(NSString *)type
{
#ifdef DEBUG
	NSLog(@"Considering update after receiving trigger of type '%@'.", type);
#endif
	if ([type isEqualToString:@"IP"]) {
		[self performSelector:@selector(doUpdate:)
			   withObject:type
			   afterDelay:3.0];
	} else if ([type isEqualToString:@"Wake"]) {
		[self performSelector:@selector(doUpdate:)
			   withObject:type
			   afterDelay:10.0];
	} else {
		NSLog(@"Internal Error: Unknown trigger type '%@'.", type);
	}
}

#pragma mark -
#pragma mark Bindings

- (AccountController *)accountController
{
	return accountController_;
}

@end
