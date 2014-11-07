//
//  InternodeApiFetcher.h
//  iNodeMon
//
//  Created by David Symonds on 17/10/10.
//

#import <Cocoa/Cocoa.h>


@interface InternodeApiFetcher : NSObject {
	@private
	NSURLConnection *conn_;
	NSMutableData *data_;
	BOOL failed_;
}

// Fetch the XML document at the given path, then run the given callback.
// Its single argument, an NSDictionary, will describe the response.
+ (void)fetchPath:(NSString *)path callback: (void(^)(NSDictionary*)) callback;

@end
