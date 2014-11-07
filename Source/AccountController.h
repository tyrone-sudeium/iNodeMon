//
//  AccountController.h
//  iNodeMon
//
//  Created by David Symonds on 12/10/08.
//

#import <Cocoa/Cocoa.h>


@class AccountHistory;
@class AccountStatus;


// Controls the retrieval of account information such as current usage and usage history.
@interface AccountController : NSObject {
	NSString *serviceId_;
	AccountStatus *accountStatus_;
	AccountHistory *accountHistory_;

	NSLock *updateLock_;

	NSConditionLock *semaphoreCondition_;	// 1 = still running updates, 0 = finished
	int semaphore_;
	BOOL reupdateImmediately_;

	NSDate *lastUpdateOfQuota_, *lastUpdateOfServiceInfo_, *lastUpdateOfHistory_;
}

- (void)update;

// Bindings (read-only)
- (AccountStatus *)accountStatus;
- (AccountHistory *)accountHistory;
- (BOOL)isUpdating;

@end
