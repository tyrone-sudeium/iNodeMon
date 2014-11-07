//
//  HistoryGraph.h
//  iNodeMon
//
//  Created by David Symonds on 21/03/08.
//

#import <Cocoa/Cocoa.h>


@class AccountController;


@interface HistoryGraph : NSView {
	AccountController *accountController_;
	NSMutableArray *toolTipLabels_;
}

- (void)setAccountController:(AccountController *)accountController;

@end
