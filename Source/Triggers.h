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
+ (void)registerForIPChangeTrigger:(NSObject *)targetObject selector:(SEL)selector;
+ (void)registerForWakeTrigger:(NSObject *)targetObject selector:(SEL)selector;

@end
