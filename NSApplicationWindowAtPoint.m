//
//  NSApplicationWindowAtPoint.m
//  UKDockableWindow
//
//  Created by Uli Kusterer on Wed Feb 04 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "NSApplicationWindowAtPoint.h"


@implementation NSApplication (WindowAtPoint)

-(NSWindow*)	windowAtPoint: (NSPoint)pos ignoreWindow: (NSWindow*)ignorew
{
	// Block below assumes the following values:
	assert(NSOrderedAscending == -1);
	assert(NSOrderedDescending == 1);
	assert(NSOrderedSame == 0);
	NSArray*		winArray = [[self windows] sortedArrayUsingComparator:^(id obj1, id obj2)
		{
			NSComparisonResult	compResult = [obj1 orderedIndex] -[obj2 orderedIndex];
			if( compResult > 1 ) compResult = 1;
			if( compResult < -1 ) compResult = -1;
			return compResult;
		}];
	NSEnumerator*   enny = [winArray objectEnumerator];
	NSWindow*		theWin = nil;
	
	while( theWin = [enny nextObject] )
	{
		if( theWin == ignorew )		// Skip the window to ignore.
			continue;
		
		if( ![theWin isVisible] )   // Skip invisible windows.
			continue;
		
		if( NSPointInRect( pos, [theWin frame] ) )
			return theWin;
	}
	
	return nil;
}

@end
