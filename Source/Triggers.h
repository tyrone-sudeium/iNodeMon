//
//  Triggers.h
//  iNodeMon
//
//  Created by David Symonds on 4/4/08.
//

#import <Cocoa/Cocoa.h>


@interface Triggers : NSObject {
}

// Each 'selector' in the following triggers should be of the form:
//   - (void)fooBar:(NSString *)type
// 'type' will be something like "IP", "Wake"

+ (void) setIPChangedBlock: (dispatch_block_t) block;
+ (void) setWakeBlock: (dispatch_block_t) block;

@end
