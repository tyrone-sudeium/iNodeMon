//
//  HistoryGraph.m
//  iNodeMon
//
//  Created by David Symonds on 21/03/08.
//

#import "AccountController.h"
#import "AccountHistory.h"
#import "AccountStatus.h"
#import "HistoryGraph.h"


@interface HistoryGraph (Private)

- (NSColor *)colorForRelativeUsage:(float)relUsage;

@end

#pragma mark -

@implementation HistoryGraph

- (id)initWithFrame:(NSRect)frame
{
	if (!(self = [super initWithFrame:frame]))
		return nil;

	accountController_ = nil;
	toolTipLabels_ = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[accountController_ release];
	[toolTipLabels_ release];

	[super dealloc];
}

- (void)setAccountController:(AccountController *)accountController
{
	if (accountController_) {
		[accountController_ removeObserver:self forKeyPath:@"accountHistory"];
		[accountController_ autorelease];
	}
	accountController_ = [accountController retain];
	[accountController_ addObserver:self forKeyPath:@"accountHistory" options:0 context:nil];
}

- (void)awakeFromNib
{
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"NumDaysOfHistory" options:0 context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	[self removeAllToolTips];

	// Start with white background, black border
	[[NSColor whiteColor] set];
	[NSBezierPath fillRect:rect];
	[[NSColor blackColor] set];
	[NSBezierPath strokeRect:rect];

	AccountHistory *history = [accountController_ accountHistory];
	AccountStatus *status = [accountController_ accountStatus];

	[history lock];

	int numDaysToGraph = [[NSUserDefaults standardUserDefaults] integerForKey:@"NumDaysOfHistory"];
	if (numDaysToGraph < 5)
		numDaysToGraph = 5;
	if (numDaysToGraph > [history numDays])
		numDaysToGraph = [history numDays];

	// Date format for tooltips
	NSString *dateFormat = @"%a %d %b";
	if (numDaysToGraph >= 365)
		dateFormat = @"%a %d %b %Y";

	float idealMBPerDay = [status quotaTotal] / [status daysInPeriod];
	if (idealMBPerDay < 1.0)
		idealMBPerDay = 1.0;	// safety

	// Peak Y axis goes to maximum usage point (but at least the ideal usage),
	// plus 5%, rounded up to next 10 MB
	float peak = [history maxInLastDays:numDaysToGraph];
	if (peak < idealMBPerDay)
		peak = idealMBPerDay;
	peak += (10 - fmod(peak * 1.05, 10));

	// Scaling factors
	float pixelsPerDay = rect.size.width / numDaysToGraph;
	float pixelsPerMB = (rect.size.height * 0.95) / peak;

	// Start with "ideal" usage line
	NSBezierPath *idealLine = [NSBezierPath bezierPath];
	[idealLine setLineWidth:1.0];
	NSPoint pt = NSMakePoint(rect.origin.x, rect.origin.y + idealMBPerDay * pixelsPerMB);
	[idealLine moveToPoint:pt];
	pt.x += rect.size.width;
	[idealLine lineToPoint:pt];
	[[NSColor redColor] set];
	[idealLine stroke];

	// Tooltip for ideal line
	NSString *toolTip = [NSString stringWithFormat:@"Ideal daily use: %.1f MB", idealMBPerDay];
	NSRect idealLineRect = NSMakeRect(rect.origin.x, pt.y - 3, rect.size.width, 6);
	[self addToolTipRect:idealLineRect owner:toolTip userData:nil];

	// Draw data for each day, stepping backwards chronologically.
	int ago;
	for (ago = 0; ago < numDaysToGraph; ++ago) {
		float usage = [history usageFrom:ago];
		NSCalendarDate *date = [[history lastDate] dateByAddingYears:0 months:0 days:-ago
									      hours:0 minutes:0 seconds:0];

		// Vertical bar for the day's usage
		NSRect usageRect = NSMakeRect(rect.origin.x + rect.size.width - (ago + 1) * pixelsPerDay,
					      rect.origin.y,
					      pixelsPerDay,
					      usage * pixelsPerMB);

		// Draw a coloured bar
		[[self colorForRelativeUsage:(usage / idealMBPerDay)] set];
		[NSBezierPath fillRect:usageRect];

		// Black border
		[[NSColor blackColor] set];
		[NSBezierPath strokeRect:usageRect];

		// Create a tooltip over that whole bar (minimum 20px high)
		toolTip = [NSString stringWithFormat:@"%.1f MB (%@)", usage,
			[date descriptionWithCalendarFormat:dateFormat]];
		if (usageRect.size.height < 20)
			usageRect.size.height = 20;
		[self addToolTipRect:usageRect owner:toolTip userData:nil];
	}

	[history unlock];
}

- (void)removeAllToolTips
{
	[super removeAllToolTips];
	[toolTipLabels_ removeAllObjects];
}

- (NSToolTipTag)addToolTipRect:(NSRect)aRect owner:(id)anObject userData:(void *)userData
{
	// By default, NSView doesn't retain the tooltip "owner", so we can't use autoreleased NSString objects.
	// We just override that behaviour to keep track of them all in a simple NSMutableArray.
	[toolTipLabels_ addObject:anObject];
	return [super addToolTipRect:aRect owner:anObject userData:userData];
}

#pragma mark -

- (NSColor *)colorForRelativeUsage:(float)relUsage
{
	// "Good" colour is sky blue
	NSColor *goodColor = [NSColor colorWithDeviceRed:0.4 green:0.8 blue:1.0 alpha:1.0];
	// Fully "bad" colour is red
	NSColor *badColor = [NSColor redColor];

	if (relUsage <= 1) {
		// "Good" usage
		return goodColor;
	} else {
		// "Bad" usage
		// Linear scale from goodColour to badColor (capped), mixed by RGB.
		static float peak = 4.0;
		float scale = (((relUsage <= peak) ? relUsage : peak) - 1.0) / (peak - 1.0);
		return [goodColor blendedColorWithFraction:scale ofColor:badColor];
	}
}

@end
