//
//  PrefsController.h
//  iNodeMon
//
//  Created by David Symonds on 8/03/08.
//

#import <Cocoa/Cocoa.h>


@class EMGenericKeychainItem;
@class SUUpdater;

@interface PrefsController : NSObject {
	IBOutlet NSTextField *usernameField, *passwordField;
	IBOutlet SUUpdater *updater;
}

- (IBAction)checkForUpdatesChanged:(id)sender;

@property (nonatomic, readonly, strong) EMGenericKeychainItem *keychainItem;

@end
