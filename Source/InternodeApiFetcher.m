//
//  InternodeApiFetcher.m
//  iNodeMon
//
//  Created by David Symonds on 17/10/10.
//

#import "EMKeychainItem.h"
#import "EMKeychainProxy.h"
#import "InternodeApiFetcher.h"


@interface InternodeApiFetcher (Private)
@property (nonatomic, strong) void(^callback)(NSDictionary*);
- (void)runCallback;

@end

#pragma mark -

@implementation InternodeApiFetcher

- (instancetype)initWithPath:(NSString *)path callback: (void(^)(NSDictionary*)) callback
{
	if (!(self = [super init]))
		return nil;

	data_ = [[NSMutableData alloc] init];

    self.callback = callback;
	failed_ = NO;

	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString *url = [[infoDict valueForKey:@"InternodeAPI"] stringByAppendingString:path];
	NSString *userAgent = [NSString stringWithFormat:@"iNodeMon/%@",
			       [infoDict valueForKey:@"CFBundleShortVersionString"]];

	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
							   cachePolicy:NSURLRequestReloadIgnoringCacheData
						       timeoutInterval:10.0];
	[req setValue:userAgent forHTTPHeaderField:@"User-Agent"];

#ifdef DEBUG
	NSLog(@"firing off request...");
#endif
	conn_ = [[NSURLConnection alloc] initWithRequest:req delegate:self];
	if (!conn_) {
		NSLog(@"Failed initialising NSURLConnection!");
		failed_ = YES;
		[self runCallback];
	}

	return self;
}

+ (void)fetchPath:(NSString *)path object:(id)object selector:(SEL)selector
{
	// The created object here will self-destruct after invoking the callback.
//	[[self alloc] initWithPath:path object:object selector:selector];
    // Deprecated
}

static NSMutableSet *runningFetchers = nil;

static void AddFetcher(InternodeApiFetcher *fetcher) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (runningFetchers == nil) {
            runningFetchers = [NSMutableSet new];
        }
        if (fetcher) {
            [runningFetchers addObject: fetcher];
        }
    });
}

static void RemoveFetcher(InternodeApiFetcher *fetcher) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (runningFetchers == nil) {
            runningFetchers = [NSMutableSet new];
        }
        if (fetcher) {
            [runningFetchers removeObject: fetcher];
        }
    });
}

+ (void)fetchPath:(NSString *)path callback:(void (^)(NSDictionary *))callback
{
    AddFetcher([[self alloc] initWithPath: path callback: callback]);
}


- (void)runCallback
{
#ifdef DEBUG
	NSLog(@"Raw response:\n-----\n%@\n-----",
	      [[NSString alloc] initWithData:data_ encoding:NSUTF8StringEncoding]);
#endif
	NSError *error = nil;
	NSXMLDocument *doc = nil;
	if (!failed_) {
		doc = [[NSXMLDocument alloc] initWithData:data_ options:0 error:&error];
		if (!doc)
			NSLog(@"Bad XML document: %@", [error localizedDescription]);
	} else {
		// TODO: more useful errors here!
		error = [NSError errorWithDomain:@"iNodeMon" code:2 userInfo:nil];
	}
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
					doc, @"document",
					error, @"error",
					nil];
    if (self.callback) {
        self.callback(result);
    }

    RemoveFetcher(self);
}

// Copied out of PrefsController.m.
// TODO: Factor these mechanics somewhere better.
- (EMGenericKeychainItem *)keychainItem
{
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
	if (!username)
		return nil;
	return [[EMKeychainProxy sharedProxy] genericKeychainItemForService:@"iNodeMon" withUsername:username];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
#ifdef DEBUG
	NSLog(@"connection:didFailWithError: called! (%@)", error);
#endif
	// TODO: more useful error message
	failed_ = YES;
	[self runCallback];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
#ifdef DEBUG
	NSLog(@"connection:didReceiveAuthenticationChallenge: called!");
#endif
	if ([challenge previousFailureCount] > 0) {
		// Bad username/password; don't keep retrying.
		NSLog(@"Username/password was rejected.");
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		return;
	}

	// Retrieve username and password from Keychain
	EMKeychainItem *kcItem = [self keychainItem];
	if (!kcItem) {
		NSLog(@"Damn, didn't get keychain item.");
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		return;
	}
	NSURLCredential *credential = [NSURLCredential credentialWithUser:[kcItem username]
								 password:[kcItem password]
							      persistence:NSURLCredentialPersistenceNone];
	[[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
#ifdef DEBUG
	NSLog(@"got %lu bytes more data...", (unsigned long)[data length]);
#endif
	[data_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self runCallback];
}

@end
