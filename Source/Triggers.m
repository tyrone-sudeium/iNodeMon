//
//  Triggers.m
//  iNodeMon
//
//  Created by David Symonds on 4/4/08.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "Triggers.h"

@implementation Triggers

static dispatch_block_t ipChangedBlock = NULL;
static void ipChangeCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    if (ipChangedBlock != NULL) {
        ipChangedBlock();
    }
}

+ (void) setIPChangedBlock:(dispatch_block_t)block
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SCDynamicStoreContext ctxt;
        ctxt.version = 0;
        ctxt.info = NULL;
        ctxt.retain = NULL;
        ctxt.release = NULL;
        ctxt.copyDescription = NULL;
        
        SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("iNodeMon"), ipChangeCallback, &ctxt);
        CFRunLoopSourceRef runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
        NSArray *keys = [NSArray arrayWithObject:@"State:/Network/Global/IPv4"];
        SCDynamicStoreSetNotificationKeys(store, (__bridge CFArrayRef) keys, NULL);
        CFRelease(store);
        CFRelease(runLoop);
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        ipChangedBlock = block;
    });
}

+ (void) setWakeBlock:(dispatch_block_t)block
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: nil name: NSWorkspaceDidWakeNotification object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName: NSWorkspaceDidWakeNotification object: nil queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (block) {
            block();
        }
    }];
}

@end
