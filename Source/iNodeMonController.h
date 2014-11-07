//
//  iNodeMonController.h
//  iNodeMon
//
//  Created by David Symonds on 25/01/07.
//
#import <Cocoa/Cocoa.h>


@class AccountController;
@class HistoryGraph;
@class PrefsController;


@interface iNodeMonController : NSObject
{
	AccountController *accountController_;
	IBOutlet PrefsController *prefsController;
	IBOutlet NSWindow *prefsWindow, *historyWindow;
	IBOutlet NSMenu *statusbarMenu;
	IBOutlet NSMenuItem *quickLinksMenuItem;

	NSStatusItem *statusItem;
	NSImage *imageIdle, *imageActive;

	NSTimer *updatingTimer;

	// Display settings
	IBOutlet NSArrayController *displayOptionsController, *historyPeriodsController;

	// Ugly, misplaced hook.
	IBOutlet HistoryGraph *historyGraph;
}

- (IBAction)doUpdate:(id)sender;
- (IBAction)doAbout:(id)sender;
- (IBAction)doPreferences:(id)sender;
- (IBAction)doHistory:(id)sender;

// Bindings
@property (nonatomic, readonly, strong) AccountController *accountController;

@end
