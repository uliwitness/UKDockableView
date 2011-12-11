// =============================================================================
//  UKDockableView.m
//  UKDockableWindow
//
//  Created by Uli Kusterer on Tue Feb 03 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//
//  PURPOSE:
//		UKDockableView attempts to provide advanced window management with a
//		simple user interface. Some people prefer applications with one large
//		window that contains everything they work with. Others prefer having
//		lots of small windows they can move around and resize.
//
//		Since in many cases there isn't really any "right way" to do it, this
//		class intends to allow splitting each NSindow into several smaller
//		"windows". These smaller parts can be grabbed and dragged out of the
//		NSWindow they are in. Drop them in another window and they end up there,
//		drop them on the desktop and you get a new NSWindow containing only this
//		one "window".
//
//		This allows "tearing apart" a window and re-assembling it as one sees
//		fit.
//
//	DIRECTIONS:
//		UKDockableView is a container view. For each of the "windows" your
//		application has, you create one UKDockableView that contains the views
//		that should be in that "window".
//		Then distribute those UKDockableViews over all the NSWindows you want
//		the user to initially have. Usually, these are several windows, but
//		there'd still be several UKDockableViews in most NSWindows.
// =============================================================================

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "UKDockableView.h"
#import "NSApplicationWindowAtPoint.h"
#import "NSViewViewIntersectingRect.h"

#if UKDOCKABLEVIEW_SUPPORT_METAL
#import "NSBezierPathRoundRects.h"
#endif


// -----------------------------------------------------------------------------
//	Class variables / Globals:
// -----------------------------------------------------------------------------

NSWindow*		gUKDockableViewOverlayWindow = nil; // Window to use for dragging around a view.
NSWindow*		gUKDockableViewTargetWindow = nil;  // Window the mouse is over while dragging a view (not counting gUKDockableViewOverlayWindow).
NSPoint			gUKDockableViewDragPosition;		// Mouse position while we're dragging the view.


@implementation UKDockableView

// -----------------------------------------------------------------------------
//	* DESIGNATED INITIALIZER:
// -----------------------------------------------------------------------------

-(id)   initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		titleEdge = NSMinXEdge;
    }
    return self;
}


// -----------------------------------------------------------------------------
//	calculateTitlebar:content:drawbox:inRect:
//		Calculate some rectangles for the various areas of the view.
//		Except for inRect: rect, all parameters are return values.
// -----------------------------------------------------------------------------

-(void)   calculateTitlebar: (NSRect*)titlebar content: (NSRect*)contentbox drawbox: (NSRect*)drawbox
				inRect: (NSRect)rect
{
	*drawbox = rect;
	
	drawbox->origin.x += 0.5; drawbox->origin.y += 0.5;
	drawbox->size.width -= 1; drawbox->size.height -= 1;
	
	NSDivideRect( *drawbox, titlebar, contentbox, UKDOCKABLEVIEW_TITLE_BAR_SIZE, titleEdge );
}


// -----------------------------------------------------------------------------
//	drawRect:
//		Draw this view's look to make it obvious to the user that it can be
//		dragged, and what controls will be dragged out.
// -----------------------------------------------------------------------------

-(void) drawRect:(NSRect)rect
{
	NSRect		drawbox,
				contentbox,
				titlebar;
	#if UKDOCKABLEVIEW_SUPPORT_METAL
	BOOL		roundCorners = ([[self window] styleMask] & NSTexturedBackgroundWindowMask) == NSTexturedBackgroundWindowMask;
	#endif
	
	[self calculateTitlebar: &titlebar content: &contentbox drawbox: &drawbox
				inRect: [self bounds]];
	
	// Content background:
	[[NSColor colorWithCalibratedWhite: 0.5 alpha: 0.1] set];
	#if UKDOCKABLEVIEW_SUPPORT_METAL
	if( roundCorners )
		[NSBezierPath fillRoundRectInRect: drawbox radius: UKDOCKABLEVIEW_CORNER_RADIUS];
	else
	#endif
		[NSBezierPath fillRect: drawbox];
	
	// Title bar:
    [[NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.6 alpha: 0.1] set];
	#if UKDOCKABLEVIEW_SUPPORT_METAL
	if( roundCorners )
		[NSBezierPath fillRoundRectInRect: titlebar radius: UKDOCKABLEVIEW_CORNER_RADIUS];
	else
	#endif
		[NSBezierPath fillRect: titlebar];
	
	// Titlebar widgets:
	NSImage*	grippy = [NSImage imageNamed: @"grippy"];
	NSPoint		imgpos = titlebar.origin;
	imgpos.y += titlebar.size.height -[grippy size].height;
	[grippy compositeToPoint: imgpos operation: NSCompositeSourceOver];
	
	// Content box:
	[[NSColor grayColor] set];
	#if UKDOCKABLEVIEW_SUPPORT_METAL
	if( roundCorners )
		[NSBezierPath strokeRoundRectInRect: drawbox radius: UKDOCKABLEVIEW_CORNER_RADIUS];
	else
	#endif
		[NSBezierPath strokeRect: drawbox];
}


// -----------------------------------------------------------------------------
//	mouseDown:
//		Allow dragging the view out of its window.
// -----------------------------------------------------------------------------

-(void)		mouseDown: (NSEvent*)evt
{
	/*
		+++ TODO:
		The whole dragging code is buggy. The cursor sometimes "shifts" from its
		position relative to the dragged view. Should reimplement this as a loop
		that runs its own event loop using nextEventMatchingMask:... and sendEvent:
		in NSEventTrackingRunLoopMode.
	*/
	
	NSRect		drawbox,
				contentbox,
				titlebar;
	NSPoint		pos;
	
	[self calculateTitlebar: &titlebar content: &contentbox drawbox: &drawbox
				inRect: [self bounds]];
	
	gUKDockableViewDragPosition = [evt locationInWindow];
	pos = [self convertPoint: gUKDockableViewDragPosition fromView: nil];
	if( (pos.x < titlebar.origin.x)
		|| (pos.y < titlebar.origin.y)
		|| (pos.x > (titlebar.origin.x +titlebar.size.width))
		|| (pos.y > (titlebar.origin.y +titlebar.size.height)) )
		return;
	
	if( !gUKDockableViewOverlayWindow )
	{
		[self lockFocus];
		NSBitmapImageRep*   bir = [[[NSBitmapImageRep alloc] initWithFocusedViewRect: [self bounds]] autorelease];
		[self unlockFocus];
		
		NSImage*			img = [[[NSImage alloc] init] autorelease];
		NSRect				box = [self frame];
		box.origin = [self convertPoint: NSMakePoint(0,0) toView: nil];
		NSPoint		diff = [[self window] contentRectForFrameRect: [[self window] frame]].origin;
		box.origin.x += diff.x;
		box.origin.y += diff.y;
		
		[img addRepresentation: bir];
		
		gUKDockableViewOverlayWindow = [[NSWindow alloc] initWithContentRect: box styleMask: NSBorderlessWindowMask
																backing:NSBackingStoreBuffered defer:YES];
		NSImageView*		imgVw = [[[NSImageView alloc] initWithFrame: [self bounds]] autorelease];
		[imgVw setImage: img];
		[[gUKDockableViewOverlayWindow contentView] addSubview: imgVw];
		
		if( [gUKDockableViewOverlayWindow respondsToSelector: @selector(setAlphaValue:)] )
			[gUKDockableViewOverlayWindow setAlphaValue: 0.8];
		[gUKDockableViewOverlayWindow orderFront: nil];
		
		[[self window] setAcceptsMouseMovedEvents: YES];
	}
}


// -----------------------------------------------------------------------------
//	mouseDragged:
//		I should probably rename this. This catches mouseDragged: events to the
//		application while the view image is being dragged to move the view.
// -----------------------------------------------------------------------------

-(void)		mouseDragged: (NSEvent*)evt
{
	NSPoint		pos,
				globalPos;
	NSRect		winBox;
	
	if( !gUKDockableViewOverlayWindow )
		return;
	
	winBox = [[self window] contentRectForFrameRect: [[self window] frame]];
	pos = [evt locationInWindow];
	globalPos.x = pos.x +winBox.origin.x;
	globalPos.y = pos.y +winBox.origin.y;
	
	if( gUKDockableViewOverlayWindow
		&& (gUKDockableViewDragPosition.x != pos.x || gUKDockableViewDragPosition.y != pos.y) )
	{
		NSRect				box = [gUKDockableViewOverlayWindow frame];
		
		box.origin.x += pos.x -gUKDockableViewDragPosition.x;
		box.origin.y += pos.y -gUKDockableViewDragPosition.y;
		
		gUKDockableViewTargetWindow = [NSApp windowAtPoint: globalPos ignoreWindow: gUKDockableViewOverlayWindow];
		
		[gUKDockableViewOverlayWindow setFrame: box display: YES];
		
		gUKDockableViewDragPosition = pos;
	}
}



// -----------------------------------------------------------------------------
//	mouseUp:
//		I should probably rename this. This catches mouseUp: events to the
//		application while the view image is being dragged to terminate the drag.
// -----------------------------------------------------------------------------

-(void) mouseUp: (NSEvent*)evt
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	if( !gUKDockableViewOverlayWindow )
		return;
	
	NSPoint		diff;
	NSRect		newbox = [gUKDockableViewOverlayWindow contentRectForFrameRect: [gUKDockableViewOverlayWindow frame]],
				oldbox = [[self window] contentRectForFrameRect: [[self window] frame]];
	diff = [self convertPoint: NSMakePoint(0,0) toView: nil];
	oldbox.origin.x += diff.x;
	oldbox.origin.y += diff.y;

	diff.x = newbox.origin.x -oldbox.origin.x;
	diff.y = newbox.origin.y -oldbox.origin.y;
	
	if( diff.x < 0 )
		diff.x = -diff.x;
	if( diff.y < 0 )
		diff.y = -diff.y;

	if( diff.x > 16 || diff.y > 16 )		// User moved it a substantial distance and didn't just mis-click?
	{
		NSWindow*			oldWin = [self window];
		NSWindow*			newWin = nil;
		NSView*				collisionView = nil;
		if( gUKDockableViewTargetWindow )
			newWin = gUKDockableViewTargetWindow;
		else
			newWin = [[NSWindow alloc] initWithContentRect: newbox
												styleMask: [oldWin styleMask]
												backing:NSBackingStoreBuffered defer:YES];
		NSWindowController* wc = [oldWin windowController];
		NSDocument*			doc = [wc document];
		NSRect				newBox = NSMakeRect(0,0,[self frame].size.width,[self frame].size.height);
		NSRect				screenBox = [[newWin screen] frame];
		float				nextRowStartY = -1;
		
		while( (collisionView = [[newWin contentView] subviewIntersectingRect: newBox ignoring: self]) )
		{
			if( nextRowStartY == -1 )
				nextRowStartY = NSMaxY([collisionView frame]);
			newBox.origin.x = NSMaxX([collisionView frame]);
			if( (newBox.origin.x +newBox.size.width) > screenBox.size.width )
			{
				newBox.origin.x = 0;
				newBox.origin.y = nextRowStartY;
				nextRowStartY = -1;
			}
		}
		
		[self retain];
		[self removeFromSuperview];
		[[newWin contentView] addSubview: self];
		[self setFrameOrigin: newBox.origin];
		[self release];
		
		NSSize  oldSuperSize = [[newWin contentView] frame].size,
				minSuperSize = [[newWin contentView] subviewsCombinedSize];
		if( oldSuperSize.width > minSuperSize.width )
			minSuperSize.width = oldSuperSize.width;
		if( oldSuperSize.height > minSuperSize.height )
			minSuperSize.height = oldSuperSize.height;
		
		[newWin setContentSize: minSuperSize];
		
		// If there's a document for the old window, create a new window controller of the same class as the old window's and add it to that document:
		if( !gUKDockableViewTargetWindow )
		{
			if( wc )
			{
				NSWindowController*		myWC = [[[[wc class] alloc] initWithWindow: newWin] retain];
				
				if( doc )
				{
					[doc addWindowController: myWC];
					[myWC synchronizeWindowTitleWithDocumentName];
				}
				else
					[newWin setTitle: [oldWin title]];
				
				if( [[[oldWin contentView] subviews] count] == 0 )
					[wc close];
			}
			else
			{
				[newWin setTitle: [oldWin title]];
				if( [[[oldWin contentView] subviews] count] == 0 )
					[oldWin close];
			}
		}
		else
		{
			if( [[[oldWin contentView] subviews] count] == 0 )
				[oldWin close];
		}
		
		[newWin makeKeyAndOrderFront: nil];
	}
	
	[gUKDockableViewOverlayWindow release];
	gUKDockableViewOverlayWindow = nil;
	gUKDockableViewTargetWindow = nil;
}


// -----------------------------------------------------------------------------
//	mouseDownCanMoveWindow:
//		Otherwise our brushed-metal window moves when our drag area is clicked.
//
//		I wanted to make this depend on whether the user clicked the content or
//		the drag area of this view, but sadly this is called only once when the
//		view is added to a window.
// -----------------------------------------------------------------------------

-(BOOL) mouseDownCanMoveWindow
{
	return NO;
	
	/*NSRect		drawbox,
				contentbox,
				titlebar;
	NSPoint		pos = [[[self window] currentEvent] locationInWindow];
	
	pos = [self convertPoint: pos fromView: nil];
	[self calculateTitlebar: &titlebar content: &contentbox drawbox: &drawbox
				inRect: [self bounds]];
	return( (pos.x < titlebar.origin.x)
			|| (pos.y < titlebar.origin.y)
			|| (pos.x > (titlebar.origin.x +titlebar.size.width))
			|| (pos.y > (titlebar.origin.y +titlebar.size.height)) );*/	
}


// -----------------------------------------------------------------------------
//	titleEdge:
//		Accessor to find out on which edge this view will draw its dragging
//		area and the little grippy-thingie.
// -----------------------------------------------------------------------------

-(NSRectEdge)	titleEdge
{
    return titleEdge;
}

// -----------------------------------------------------------------------------
//	setTitleEdge:
//		Mutator to specify on which edge this view will draw its dragging
//		area and the little grippy-thingie. NSMinXEdge (left) is the default,
//		and NSMaxYEdge (top) is a sensible alternative. Avoid the right edge
//		because that's where the scrollbar usually is, and *never* use the
//		bottom edge because it feals really weird to be dragging something by
//		its bottom. Just MHO.
// -----------------------------------------------------------------------------

-(void)	setTitleEdge: (NSRectEdge)newTitleEdge
{
	titleEdge = newTitleEdge;
	[self setNeedsDisplay: YES];
}



@end
