//
//  PrefsController.m
//  iNodeMon
//
//  Created by David Symonds on 8/03/08.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/SUUpdater.h>
#import "EMKeychainProxy.h"
#import "PrefsController.h"


#pragma mark -

@implementation PrefsController

- (void)awakeFromNib
{
	// Load existing username/password
	EMGenericKeychainItem *kcItem = [self keychainItem];
	if (kcItem) {
		if ([kcItem username])
			[usernameField setStringValue:[kcItem username]];
		if ([kcItem password])
			[passwordField setStringValue:[kcItem password]];
	}
}

- (IBAction)checkForUpdatesChanged:(id)sender
{
	BOOL val = [[NSUserDefaults standardUserDefaults] boolForKey:@"CheckForUpdates"];

	NSTimeInterval intv;
	if (val) {
		// Revert to setting in Info.plist
		intv = [[[[NSBundle mainBundle] infoDictionary] valueForKey:@"SUScheduledCheckInterval"] doubleValue];
	} else {
		// Disable update checking
		intv = 0;
	}
#ifdef DEBUG
	NSLog(@"Changing Sparkle update interval to %f", intv);
#endif
	[[NSUserDefaults standardUserDefaults] setValue: @((long)intv)
						 forKey:@"SUScheduledCheckInterval"];
	[updater scheduleCheckWithInterval:intv];
}

- (EMGenericKeychainItem *)keychainItem
{
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
	if (!username)
		return nil;
	return [[EMKeychainProxy sharedProxy] genericKeychainItemForService:@"iNodeMon" withUsername:username];
}

#pragma mark Window delegates

- (void)windowWillClose:(NSNotification *)notification
{
	// Create/Update keychain
	EMGenericKeychainItem *kcItem = [self keychainItem];
	if (!kcItem) {
		[[EMKeychainProxy sharedProxy] addGenericKeychainItemForService:@"iNodeMon"
								   withUsername:[usernameField stringValue]
								       password:[passwordField stringValue]];
	} else {
		[kcItem setUsername:[usernameField stringValue]];
		[kcItem setPassword:[passwordField stringValue]];
	}

	// Remember the username
	[[NSUserDefaults standardUserDefaults] setValue:[usernameField stringValue]
						 forKey:@"username"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
